#!/usr/bin/lua

-- wbgen2, (c) 2010 Tomasz Wlostowski/CERN BE-Co-HT
-- LICENSED UNDER GPL v2

-- File: cgen_python_headers.lua
--
-- The C header code generator.
--

-- generates #defines for a register field:
-- NAME_MASK - bit mask of the field
-- NAME_SHIFT - bit offset of the field
-- NAME_W - write access macro packing given field value into the register:
-- regs_struct->reg = FIELD1_W(value1) | FIELD2_W(value2) | ....;
--
-- NAME_R - read access macro extracting the value of certain field from the register: 
-- field1_value = FIELD1_R(regs_struct->reg);
--

function DEC_HEX(IN)
    return "\"0x"..DEC_HEX2(IN) .. "\""
end

function DEC_HEX2(IN)
    local B,K,OUT,I,D=16,"0123456789ABCDEF","",0
    if IN == 0 then
      return "0"
    end
    while IN>0 do
        I=I+1
        IN,D=math.floor(IN/B),math.mod(IN,B)+1
        OUT=string.sub(K,D,D)..OUT
    end
    return OUT
end

function access_translate( type )
   if type == 1 then
      return "\"r\""
   elseif type == 2 then
      return "\"rw\""
   elseif type == 4 then
      return "\"w\""
   end
end 

function cgen_python_field_define(field, reg)
   local prefix;
   -- anonymous field?
   if(field.c_prefix == nil) then
      return ;
   else
      prefix=string.upper(periph.c_prefix).."_"..string.upper	(reg.c_prefix).."_"..string.upper(field.c_prefix);	
   end
   
   emit("<node id=\""..field.c_prefix.."\" mask="..DEC_HEX( 2^( field.size +field.offset) - 2^field.offset ).." permission="..access_translate(field.access_bus).."/>");
   -- -- for bit-type fields, emit only masks
   -- if(field.type == BIT or field.type == MONOSTABLE)  then
   --    emit("\t<node id=\""..field.c_prefix.."\" mask="..DEC_HEX( field.offset ).." permission="..access_translate(field.access_bus).."/>");

   -- else 
   --    emit("\t<node id=\""..field.c_prefix.."\" mask="..DEC_HEX( 2^( field.size +field.offset) - 2^field.offset ).." permission="..access_translate(field.access_bus).."/>");

   -- end	
end


-- generates some definitions for RAM memory block
function cgen_python_ramdefs(ram)
   local prefix = string.upper(periph.c_prefix).."_"..string.upper(ram.c_prefix);
   
   emit("/* definitions for RAM: "..ram.name.." */");	
   
   emit(string.format("#define "..prefix.."_BASE 0x%08x %-50s", ram.base * DATA_BUS_WIDTH/8, "/* base address */"));
   emit(string.format("#define "..prefix.."_BYTES 0x%08x %-50s", ram.size * ram.width / 8, "/* size in bytes */"));
   emit(string.format("#define "..prefix.."_WORDS 0x%08x %-50s", ram.size, "/* size in "..ram.width.."-bit words, 32-bit aligned */"));
end




-- iterates all regs and rams and generates appropriate #define-s
function cgen_python_field_masks()
   foreach_reg({TYPE_REG}, function(reg)
         -- print("DOCREG: ", reg.name, reg.num_fields);
         dbg("DOCREG: ", reg.name, reg.num_fields);
         if(reg.num_fields ~= nil and reg.num_fields > 0) then
            emit("");
            if ( reg.num_fields == 1) then 
               -- print( reg.doc_is_fiforeg )
               if ( reg.doc_is_fiforeg == true ) then
                  emit("<node id=\""..reg.c_prefix.."\" address="..DEC_HEX(reg.base).." permission="..access_translate(reg[1].access_bus).." mode=\"port\"/>"  );
               else
                  emit("<node id=\""..reg.c_prefix.."\" address="..DEC_HEX(reg.base).." permission="..access_translate(reg[1].access_bus).."/>");
               end
            else
               emit("<node id=\""..reg.c_prefix.."\" address="..DEC_HEX(reg.base)..">");
               indent_right()
               foreach_subfield(reg, function(field, reg) cgen_python_field_define(field, reg) end);
               indent_left()
               emit("</node>");
            end
         end
      end
   );
   
   foreach_reg({TYPE_RAM}, function(ram)
         cgen_python_ramdefs(ram);
      end
   );
end


-- generates C file header
function cgen_python_fileheader()
   emit ("<!--");
   emit ("  Register definitions for slave core: "..periph.name);
   emit ("");
   emit ("  * File           : "..options.output_c_header_file);
   emit ("  * Author         : auto-generated by wbgen2 from "..input_wb_file);
   emit ("  * Created        : "..os.date());
   emit ("");
   emit ("    THIS FILE WAS GENERATED BY wbgen2 FROM SOURCE FILE "..input_wb_file);
   emit ("    DO NOT HAND-EDIT UNLESS IT'S ABSOLUTELY NECESSARY!");
   emit ("");
   emit ("-->");
   emit("");
  
end

-- generates C structure reflecting the memory map of the peripheral.
function cgen_python_struct()
   local cur_offset = 0;
   local pad_id = 0;
   
-- generates padding entry (if the offset of the register in memory is ahead of current offset in the structure)	
   function pad_struct(base)
      if(cur_offset < base) then
	 emit("/* padding to: "..base.." words */");
	 emit("uint32_t __padding_"..pad_id.."["..(base - cur_offset).."];");
	 pad_id=pad_id+1;
	 cur_offset = base;
      end
   end
   
   -- emit the structure definition...
   emit("");
   emit("PACKED struct "..string.upper(periph.c_prefix).."_WB {");
   indent_right();
   
   
   -- emit struct entires for REGs
   foreach_reg({TYPE_REG}, function(reg)
			      --								print(reg.name, reg.prefix, reg.c_prefix, reg.hdl_prefix);
			      pad_struct(reg.base);
			      emit(string.format("/* [0x%x]: REG "..reg.name.." */", reg.base * DATA_BUS_WIDTH / 8));
			      
			      -- this is just simple :)
			      emit("uint32_t "..string.upper(reg.c_prefix)..";");
			      cur_offset = cur_offset + 1;
			   end);
   
   -- .. and for RAMs
   foreach_reg({TYPE_RAM}, function(ram)
			      
			      -- calculate base address of the RAM
			      
			      --	print("SelBits: ram "..ram.name.." sb "..ram.select_bits);
			      local base = ram.select_bits * 
				 math.pow (2, address_bus_width - address_bus_select_bits);									
			      
			      pad_struct(base);									
			      
			      -- output some comments
			      emiti();
			      emitx(string.format("/* [0x%x - 0x%x]: RAM "..ram.name..", "..ram.size.." "..ram.width.."-bit words, "..DATA_BUS_WIDTH.."-bit aligned, "..csel(ram.byte_select, "byte", "word").."-addressable", base * DATA_BUS_WIDTH / 8, (base + math.pow(2, ram.wrap_bits)*ram.size) * (DATA_BUS_WIDTH / 8) - 1));
			      
			      if(ram.wrap_bits > 0) then
				 emitx(", mirroring: "..math.pow(2, ram.wrap_bits).." times */\n");
			      else
				 emitx(" */\n");
			      end
			      
			      -- and the RAM, as an array
			      if(ram.byte_select) then
				 emit("uint8_t "..string.upper(ram.c_prefix).." ["..(ram.size * (DATA_BUS_WIDTH/8) * math.pow(2, ram.wrap_bits)) .."];");
			      else
				 emit("uint32_t "..string.upper(ram.c_prefix).." ["..(ram.size * math.pow(2, ram.wrap_bits)) .."];");									
			      end
			   end);
   
   indent_left();
   emit("};");
   emit("");	
end


function cgen_python_defines()
   foreach_reg({TYPE_REG}, function(reg)
			      emit(string.format("/* [0x%x]: REG "..reg.name.." */", reg.base * DATA_BUS_WIDTH / 8));
			      emit("#define "..string.upper(periph.c_prefix).."_REG_"..string.upper(reg.c_prefix).." "..string.format("0x%08x", reg.base * DATA_BUS_WIDTH/8));
			   end);

end


-- main C code generator function. Takes the peripheral definition and generates C code.
function cgen_generate_python_header_code()
   cgen_new_snippet();
   
   cgen_python_fileheader();
   
   emit( "<?xml version=\"1.0\" encoding=\"ISO-8859-1\"?>\n<node>)" )
   
   indent_right();
   cgen_python_field_masks();
   indent_left();

   emit( "</node>)" )
   
   cgen_write_current_snippet();
end
