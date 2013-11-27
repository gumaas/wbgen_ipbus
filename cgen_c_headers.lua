#!/usr/bin/lua

-- wbgen2, (c) 2010 Tomasz Wlostowski/CERN BE-Co-HT
-- LICENSED UNDER GPL v2

-- File: cgen_c_headers.lua
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
function cgen_c_field_define(field, reg, index)
   local prefix;
   -- anonymous field?
   if(field.c_prefix == nil) then
      return ;
   else
      prefix=string.upper(periph.c_prefix).."_"..string.upper	(reg.c_prefix).."_"..string.upper(field.c_prefix);	
   end
   
   
   emit("");
   emit("/* definitions for field: "..field.name.." in reg: "..reg.name.." */");
   if(options.c_reg_style == "extended")  then
      rw_table = {[READ_ONLY] = "READ_ONLY", [WRITE_ONLY] = "WRITE_ONLY", [READ_WRITE] = "READ_WRITE" }
      emit(string.format("%-45s %d", "#define "..prefix.."_INDEX", index));
      emit(string.format("%-45s %s", "#define "..prefix.."_PREFIX", "\""..field.c_prefix.."\""));
      emit(string.format("%-45s %s", "#define "..prefix.."_NAME", "\""..field.name.."\""));
      emit(string.format("%-45s %s", "#define "..prefix.."_DESC", "WBGEN2_DESC(\""..field.description:gsub("\n.*", "").."\")"));
      emit(string.format("%-45s %s", "#define "..prefix.."_ACCESS", "WBGEN2_"..rw_table[field.access_bus]));
      if(field.type == BIT or field.type == MONOSTABLE)  then
        emit(string.format("%-45s %s", "#define "..prefix.."_MASK", "WBGEN2_GEN_MASK("..field.offset..", "..field.size..")"));
        emit(string.format("%-45s %d", "#define "..prefix.."_SHIFT", field.offset));
      end
   end
   
   -- for bit-type fields, emit only masks
   if(field.type == BIT or field.type == MONOSTABLE)  then
      emit(string.format("%-45s %s", "#define "..prefix, "WBGEN2_GEN_MASK("..field.offset..", 1)"));

   else 
      -- SLV/signed/unsigned fields: emit masks, shifts and access macros
      
      emit(string.format("%-45s %s", "#define "..prefix.."_MASK", "WBGEN2_GEN_MASK("..field.offset..", "..field.size..")"));
      emit(string.format("%-45s %d", "#define "..prefix.."_SHIFT", field.offset));
      emit(string.format("%-45s %s", "#define "..prefix.."_W(value)", "WBGEN2_GEN_WRITE(value, "..field.offset..", "..field.size..")"));
      
      -- if the field is signed, generate read operation with sign-extension
      if(field.type == SIGNED) then
	 emit(string.format("%-45s %s", "#define "..prefix.."_R(reg)", "WBGEN2_SIGN_EXTEND(WBGEN2_GEN_READ(reg, "..field.offset..", "..field.size.."), "..field.size..")"));
      else
	 emit(string.format("%-45s %s", "#define "..prefix.."_R(reg)", "WBGEN2_GEN_READ(reg, "..field.offset..", "..field.size..")"));
      end
   end	
end


-- generates some definitions for RAM memory block
function cgen_c_ramdefs(ram)
   local prefix = string.upper(periph.c_prefix).."_"..string.upper(ram.c_prefix);
   
   emit("/* definitions for RAM: "..ram.name.." */");	
   
   emit(string.format("#define "..prefix.."_BASE 0x%08x %-50s", ram.base * DATA_BUS_WIDTH/8, "/* base address */"));
   emit(string.format("#define "..prefix.."_BYTES 0x%08x %-50s", ram.size * ram.width / 8, "/* size in bytes */"));
   emit(string.format("#define "..prefix.."_WORDS 0x%08x %-50s", ram.size, "/* size in "..ram.width.."-bit words, 32-bit aligned */"));
end

-- iterates all regs and rams and generates appropriate #define-s
function cgen_c_field_masks()
   local index;
   foreach_reg({TYPE_REG}, function(reg)
			      dbg("DOCREG: ", reg.name, reg.num_fields);
			      if(reg.num_fields ~= nil and reg.num_fields > 0) then
				 emit("");
				 emit("/* definitions for register: "..reg.name.." */");
				 index=0;
				 foreach_subfield(reg, function(field, reg) cgen_c_field_define(field, reg, index); index=index+1; end);
			      end
			   end);
   
   foreach_reg({TYPE_RAM}, function(ram)
			      cgen_c_ramdefs(ram);
			   end);
end


-- generates C file header
function cgen_c_fileheader()
   emit ("/*");
   emit ("  Register definitions for slave core: "..periph.name);
   emit ("");
   emit ("  * File           : "..options.output_c_header_file);
   emit ("  * Author         : auto-generated by wbgen2 from "..input_wb_file);
   emit ("  * Created        : "..os.date());
   emit ("  * Standard       : ANSI C");
   emit ("");
   emit ("    THIS FILE WAS GENERATED BY wbgen2 FROM SOURCE FILE "..input_wb_file);
   emit ("    DO NOT HAND-EDIT UNLESS IT'S ABSOLUTELY NECESSARY!");
   emit ("");
   emit ("*/");
   emit("");
   emit("#ifndef __WBGEN2_REGDEFS_"..string.upper(string.gsub(input_wb_file,"%.","_")))
   emit("#define __WBGEN2_REGDEFS_"..string.upper(string.gsub(input_wb_file,"%.","_")))
   emit("");
   emit("#include <inttypes.h>");
   emit("");	
   emit("#if defined( __GNUC__)");
   emit("#define PACKED __attribute__ ((packed))");
   emit("#else");
   emit("#error \"Unsupported compiler?\"");
   emit("#endif");
   emit("");
   emit("#ifndef __WBGEN2_MACROS_DEFINED__");
   emit("#define __WBGEN2_MACROS_DEFINED__");
   emit("#define WBGEN2_GEN_MASK(offset, size) (((1ULL<<(size))-1) << (offset))");
   emit("#define WBGEN2_GEN_WRITE(value, offset, size) (((value) & ((1<<(size))-1)) << (offset))");
   emit("#define WBGEN2_GEN_READ(reg, offset, size) (((reg) >> (offset)) & ((1<<(size))-1))");
   emit("#define WBGEN2_SIGN_EXTEND(value, bits) (((value) & (1<<bits) ? ~((1<<(bits))-1): 0 ) | (value))");
   if(options.c_reg_style == "extended")  then
		emit("#define WBGEN2_READ_ONLY\t0x01");
		emit("#define WBGEN2_WRITE_ONLY\t0x10");
		emit("#define WBGEN2_READ_WRITE\t(WBGEN2_READ_ONLY | WBGEN2_WRITE_ONLY)");
		emit("#ifdef __WBGEN2_ENABLE_DESC__ ");
		emit("#define WBGEN2_DESC(desc) desc");
		emit("#else");
		emit("#define WBGEN2_DESC(desc) \"\" ");
		emit("#endif");
   end
   emit("#endif");
   emit("");
end

-- generates C structure reflecting the memory map of the peripheral.
function cgen_c_struct()
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


function cgen_c_defines()
   emit(string.format(""))
   emit(string.format(""))
   foreach_reg({TYPE_REG}, function(reg)
                  local prefix = string.upper(periph.c_prefix).."_REG_"..string.upper(reg.c_prefix);
			      emit(string.format("/* [0x%x]: REG "..reg.name.." */", reg.base * DATA_BUS_WIDTH / 8));
			      if(options.c_reg_style == "extended")  then
			         emit(string.format("%-45s %s", "#define "..prefix.."_PREFIX", "\""..reg.c_prefix.."\""));
			         emit(string.format("%-45s %s", "#define "..prefix.."_NAME", "\""..reg.name.."\""));
			         emit(string.format("%-45s %s", "#define "..prefix.."_DESC", "WBGEN2_DESC(\""..reg.description:gsub("\n.*", "").."\")"));
			      end
			      emit(string.format("%-45s %s","#define "..string.upper(periph.c_prefix).."_REG_"..string.upper(reg.c_prefix),
			      string.format("0x%08x", reg.base * DATA_BUS_WIDTH/8)));
			      emit(string.format(""))
			   end);

end


-- main C code generator function. Takes the peripheral definition and generates C code.
function cgen_generate_c_header_code()
   cgen_new_snippet();
   
   cgen_c_fileheader();
   cgen_c_field_masks();
   
   if(options.c_reg_style == "struct") then
      cgen_c_struct();
   else
      cgen_c_defines();
   end

   emit("");
   emit(string.format("%-45s %s", "#define "..string.upper(periph.c_prefix).."_PERIPH_PREFIX", "\""..periph.c_prefix.."\""));
   emit(string.format("%-45s %s", "#define "..string.upper(periph.c_prefix).."_PERIPH_NAME", "\""..periph.name.."\""));
   emit(string.format("%-45s %s", "#define "..string.upper(periph.c_prefix).."_PERIPH_DESC", "WBGEN2_DESC(\""..periph.description:gsub("\n.*", "").."\")"));

   emit("\n#endif");
   cgen_write_current_snippet();
end
