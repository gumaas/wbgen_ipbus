-- -*- Mode: LUA; tab-width: 2 -*-

-- wbgen2 - a simple Wishbone slave generator
-- (c) 2010-2013 CERN
-- CERN BE-CO-HT
-- LICENSED UNDER GPL v2


------------------------------
-- HDL syntax tree constructors
------------------------------

-- assignment: dst <= src;
function va (dst, src)
  local s={};
  s.t="assign";
  s.dst=dst;
  s.src=src;
  return s;
end

-- index: name(h downto l)

function vi(name, h, l)
 local s={};
 s.t="index";
 s.name=name;
 s.h=h;
 s.l=l;
 return s;
end

-- instance of a component
function vinstance(name, component, maps)
 local s={};
 s.t="instance";
 s.name=name;
 s.component = component;
 s.maps = maps;
 return s;
end

-- port map
function vpm(to, from)
 local s={};
 s.t="portmap";
 s.to = to;
 s.from = from;
 return s;

end

-- generic map
function vgm(to, from)
 local s={};
 s.t="genmap";
 s.to = to;
 s.from = from;
 return s;

end

-- combinatorial process: process(sensitivity_list) begin {code} end process;
function vcombprocess(slist, code)
 local s={};
 s.t="combprocess";
 s.slist = slist;
 s.code=code;
 return s;
end



-- synchronous process: process(clk, rst) begin {code} end process; 
function vsyncprocess(clk, rst, code)
 local s={};
 s.t="syncprocess";
 s.clk=clk;
 s.rst=rst;
 s.code=code;
 return s;
end



-- reset in process
function vreset(level, code)
 local s={};
 s.t="reset";
 s.level=level;
 s.code=code;
 return s;
end

function vposedge(code)
 local s={};
 s.t="posedge";
 s.code=code;
 return s;
end

function vif(cond, code, code_else)
 local s={};
 s.t="if";
 s.cond={ cond };
 s.code=code;
 s.code_else=code_else;
 return s;
end

function vgenerate_if(cond, code)
 local s={};
 s.t="generate_if";
 s.cond={ cond };
 s.code=code;
 return s;
end

function vequal(a,b)
 local s={};
 s.t="eq";
 s.a=a;
 s.b=b;
 return s;
end

function vand(a,b)
 local s={};
 s.t="and";
 s.a=a;
 s.b=b;
 return s;
end

function vor(a,b)
 local s={};
 s.t="or";
 s.a=a;
 s.b=b;
 return s;
end

function vnot(a)
 local s={};
 s.t="not";
 s.a=a;
 return s;
end

function vswitch(a, code)
 local s={};
 s.t="switch";
 s.a=a;
 s.code=code;
 return s;
end

function vcase(a, code)
 local s={};
 s.t="case";
 s.a=a;
 s.code=code;
 return s;
end

function vcasedefault(code)
 local s={};
 s.t="casedefault";
 s.code=code;
 return s;
end

function vcomment(str)
 local s={};
 s.t="comment";
 s.str=str;
 return s;
end

function vsub(a,b)
 local s={};
 s.t="sub";
 s.a=a;
 s.b=b;
 return s;
end

function vothers(value)
 local s={}
 s.t="others";
 s.val=value;
 return s;
end

function vopenpin()
 local s={}
 s.t="openpin";
 return s;
end

function vundefined()
 local s={}
 s.t="undefined";
 return s;
end


-- constructor for a HDL signal
function signal(type, nbits, name, comment)
    local t = {}
    t.comment = comment;
    t.type = type;
    t.range= nbits;
    t.name = name;
    return t;
end

VPORT_WB = 1;
VPORT_REG = 2;

-- constructor for a HDL port
function port(type, nbits, dir, name, comment, extra_flags)
    local t = {}
		t.comment = comment;
    t.type = type;
    
--    if(t.type == SLV and nbits == 1) then
--    	t.type = BIT;
--    end
    
    t.range= nbits;
    t.name = name;
    t.dir = dir;


    if(extra_flags ~= nil) then
       if(extra_flags == VPORT_WB) then
          t.is_wb = true;
          t.is_reg_port = false;
       elseif(extra_flags == VPORT_REG) then
          t.is_wb = false;
          t.is_reg_port = true;
       else
          t.is_wb =false
          t.is_reg_port = false;
       end
    end
    
    return t;
end


global_ports = {};
global_signals = {};

function add_global_signals(s)
	table_join(global_signals, s);
end

function add_global_ports(p)
	table_join(global_ports, p);
end


function cgen_build_clock_list()
    local allclocks = tree_2_table("clock");
    local i,v;
    local clockports = {};
    
    allclocks = remove_duplicates(allclocks);
    
    for i,v in pairs(allclocks) do
    	table.insert(clockports, port(BIT, 0, "in", v, "", true));
    end

    return clockports;
end

function cgen_build_siglist()
	local siglist = {};
	local i,v;
	local s;
	
	siglist = tree_2_table("signals");
	
	table_join(siglist, global_signals);

	for i,v in pairs(siglist) do
	   dbg("SIGNAL: ", v.name);
	end
	
	return siglist;
end



function cgen_build_portlist()
		local portlist = {};
    table_join(portlist, global_ports);
    table_join(portlist, cgen_build_clock_list());
    table_join(portlist, tree_2_table("ports"));
		return portlist;
end

function cgen_build_optional_list()
	local t1={}
	local t2={} -- fixme: extremely ugly
	local j=1
	for i,v in pairs(tree_2_table("optional")) do
		if t1[v] == nil then
			t1[v]=1
			t2[j]=v
			j=j+1
		end
	end
		
	return t2
end

function cgen_find_sigport(name)
	for i,v in pairs(g_portlist) do if(name == v.name) then return v; end end
	for i,v in pairs(g_siglist) do if(name == v.name) then return v; end end
	for i,v in pairs(g_optlist) do if(name == v) then 
        local gp = {}
        gp.type = INTEGER;
        gp.name = v;
        return gp;
  end end
	
	die("cgen internal error: undefined signal '"..name.."'");
	
	return nil;
end

function cgen_build_signals_ports()
	g_portlist = cgen_build_portlist();
	g_siglist = cgen_build_siglist();
	g_optlist = cgen_build_optional_list();
end

cur_indent = 0;

function indent_zero()
	cur_indent=0;
end

function indent_left()
	cur_indent = cur_indent - 1;
end

function indent_right()
	cur_indent = cur_indent + 1;
end


function cgen_new_snippet()
        emit_code = "";
end
function emiti()
        local i;
        for i = 1,cur_indent do emit_code=emit_code.."  "; end
end
function emit(s)
        local i;
        for i = 1,cur_indent do emit_code=emit_code.."  "; end
        emit_code=emit_code..s.."\n";
end
function emitx(s)
        emit_code=emit_code..s;
end
function cgen_get_snippet()
  return emit_code;
end

function cgen_write_current_snippet()
	output_code_file.write(output_code_file, emit_code);
end

function cgen_write_snippet(s)
	output_code_file.write(output_code_file, s);
end


function cgen_generate_init(filename)
	output_code_file = io.open(filename, "w");
	if(output_code_file == nil) then
		die("Can't open code output file: "..filename);
	end
end

function cgen_generate_done()
	output_code_file.close(output_code_file);
end

function cgen_gen_vlog_constants(filename)
	local file = io.open(filename, "w");
 
 	if(file == nil) then
 		die("can't open "..filename.." for writing.");
 	end
	 
	  foreach_reg({TYPE_REG}, function(reg) 
				file.write(file, string.format("`define %-30s %d'h%x\n", "ADDR_"..string.upper(periph.c_prefix.."_"..reg.c_prefix), address_bus_width+2, (DATA_BUS_WIDTH/8) * reg.base));
				
				foreach_subfield(reg, function(field)
					if(field.c_prefix ~= nil) then
						file.write(file, string.format("`define %s_%s_%s_OFFSET %d\n", string.upper(periph.c_prefix), string.upper(reg.c_prefix), string.upper(field.c_prefix), field.offset));
 						file.write(file, string.format("`define %s_%s_%s 32'h%08x\n", string.upper(periph.c_prefix), string.upper(reg.c_prefix), string.upper(field.c_prefix), (math.pow(2,field.size)-1) * math.pow(2, field.offset)  ));
					end
				end);				
			end);
		
		
		foreach_reg({TYPE_RAM}, function(reg) 
				local base = reg.select_bits * 
										 math.pow (2, address_bus_width - address_bus_select_bits);				
				file.write(file, string.format("`define %-30s %d'h%x\n", "BASE_"..string.upper(periph.c_prefix.."_"..reg.c_prefix), address_bus_width+2, (DATA_BUS_WIDTH/8) *base));
				file.write(file, string.format("`define %-30s 32'h%x\n", "SIZE_"..string.upper(periph.c_prefix.."_"..reg.c_prefix), reg.size));
		end);



	io.close(file);
end
