-- -*- Mode: LUA; tab-width: 2 -*-


MAX_ACK_LENGTH = 10;

MODE_CLASSIC=1
MODE_PIPELINED=2

function gen_pipelined_wb_ports(mode)
  local ports = {
		port(BIT, 0, "in", "rst_n_i", "", VPORT_WB),
		port(BIT, 0, "in", "clk_sys_i", "", VPORT_WB),
	};
	
  if(address_bus_width > 0 ) then
		table_join(ports, { port(SLV, address_bus_width, "in", "wb_adr_i", "", VPORT_WB) })
  end

  table_join(ports, {
										port(SLV, DATA_BUS_WIDTH, "in", "wb_dat_i", "", VPORT_WB),
										port(SLV, DATA_BUS_WIDTH, "out", "wb_dat_o", "", VPORT_WB),
										port(BIT, 0, "in", "wb_cyc_i", "", VPORT_WB),
										port(SLV, math.floor((DATA_BUS_WIDTH+7)/8), "in", "wb_sel_i", "", VPORT_WB),
										port(BIT, 0, "in", "wb_stb_i", "", VPORT_WB),
										port(BIT, 0, "in", "wb_we_i", "", VPORT_WB),
										port(BIT, 0, "out", "wb_ack_o", "", VPORT_WB)
   									});

	if(mode == MODE_PIPELINED) then
		table_join(ports, {	port(BIT, 0, "out", "wb_stall_o", "", VPORT_WB) });
	end

	if(periph.irqcount > 0) then
		table_join(ports, { port(BIT, 0, "out" ,"wb_int_o", "", VPORT_WB); });
	end

    
	add_global_ports(ports);
end


function gen_pipelined_wb_signals(mode)
local width = math.max(1, address_bus_width);

local wb_sigs = {  signal(SLV, MAX_ACK_LENGTH, "ack_sreg"),
									 signal(SLV, DATA_BUS_WIDTH, "rddata_reg"),
									 signal(SLV, DATA_BUS_WIDTH, "wrdata_reg"),
 									 signal(SLV, DATA_BUS_WIDTH/8	, "bwsel_reg"),
									 signal(SLV, width, "rwaddr_reg"),
									 signal(BIT, 0, "ack_in_progress"),
 									 signal(BIT, 0, "wr_int"),
 									 signal(BIT, 0, "rd_int"),
									 signal(SLV, DATA_BUS_WIDTH, "allones"),
							 		 signal(SLV, DATA_BUS_WIDTH, "allzeros")
 				
							 };

	add_global_signals(wb_sigs);
end


-- generates the entire Wishbone bus access logic
function gen_bus_logic_pipelined_wb(mode)
  local s;

	gen_pipelined_wb_ports(mode);
	gen_pipelined_wb_signals(mode);

  foreach_reg(ALL_REG_TYPES, function(reg) 
			gen_abstract_code(reg);
    end );

	local resetcode={};
	local ackgencode={};
    local preackcode={};
	local nooperation={};
    
  foreach_field(function(field, reg) 
    table_join(resetcode, field.reset_code_main); 
  end );

  foreach_reg(ALL_REG_TYPES, function(reg) 
    table_join(resetcode, reg.reset_code_main); 
  end );


  foreach_reg({TYPE_REG}, function(reg) 
	    						foreach_subfield(reg, function(field, reg) 
							     table_join(ackgencode, field.ackgen_code); 
							     table_join(preackcode, field.ackgen_code_pre);
                                 table_join(nooperation, field.no_operation);  
								end);
							 table_join(ackgencode, reg.ackgen_code); 
					     table_join(preackcode, reg.ackgen_code_pre); 
                         table_join(nooperation, reg.no_operation); 
					    end);

	local fsmcode={};

  foreach_reg({TYPE_REG}, function(reg) 
    local acklen = find_max(reg, "acklen");
		local rcode={};
		local wcode={};
	
					
		foreach_subfield(reg, function(field, reg) table_join(wcode, field.write_code); end );
		foreach_subfield(reg, function(field, reg) table_join(rcode, field.read_code); end );		

		local padcode = fill_unused_bits("rddata_reg", reg);


		table_join(wcode, reg.write_code);
		table_join(rcode, reg.read_code);

		local rwcode = {
			vif(vequal("wb_we_i" ,1), {
	   		wcode,
			});
				rcode,
	   		padcode
			}; 


	 if(not (reg.dont_emit_ack_code == true))  then -- we don't want the main generator to mess with ACK line for this register
			table_join(rwcode, { va(vi("ack_sreg", math.max(acklen-1, 0)), 1); } );
			table_join(rwcode, { va("ack_in_progress", 1); });
	 end

   	if(regbank_address_bits > 0) then
   		rwcode = { vcase(reg.base, rwcode); }; 
   	end
		
		table_join(fsmcode, rwcode);
	end );

  if(regbank_address_bits > 0) then

		table_join(fsmcode, { vcasedefault({
			vcomment("prevent the slave from hanging the bus on invalid address");
			va("ack_in_progress", 1);
			va(vi("ack_sreg", 0), 1);
		}); });

   	fsmcode = { vswitch(vi("rwaddr_reg", regbank_address_bits - 1, 0), fsmcode); };
  end
  
  if(periph.ramcount > 0) then
		local ramswitchcode = {};
		
		if(periph.fifocount + periph.regcount > 0) then
-- append the register bank CASE statement if there are any registers or FIFOs
			ramswitchcode = { vcase (0, fsmcode); };
		end
		
		
		
	
		foreach_reg({TYPE_RAM}, function(reg) 

								local acklen = csel(options.register_data_output, 1, 0);												
								table_join(ramswitchcode, { vcase(reg.select_bits , {
									vif(vequal("rd_int" ,1), {
							 			va(vi("ack_sreg", 0), 1);
									}, {
							 			va(vi("ack_sreg", acklen), 1);
									});
									va("ack_in_progress", 1);
									} ); } );
							end);

		table_join(ramswitchcode, { 
			vcasedefault({
				vcomment("prevent the slave from hanging the bus on invalid address");
				va("ack_in_progress", 1);
				va(vi("ack_sreg", 0), 1);
			 }) 
		});

  	fsmcode = { vswitch(vi("rwaddr_reg", address_bus_width-1, address_bus_width - address_bus_select_bits), ramswitchcode); };
  end

	fsmcode = { vif(vand(vequal("wb_cyc_i", 1), vequal("wb_stb_i", 1)), { fsmcode }, {nooperation} ); };	

		local code = {
		vcomment("Some internal signals assignments. For (foreseen) compatibility with other bus standards.");

		va("wrdata_reg", "wb_dat_i");
		va("bwsel_reg", "wb_sel_i");	
		va("rd_int", vand("wb_cyc_i", vand("wb_stb_i", vnot("wb_we_i"))));
		va("wr_int", vand("wb_cyc_i", vand("wb_stb_i", "wb_we_i")));
		va("allones", vothers(1));
		va("allzeros", vothers(0));
		
		
		vcomment("");
		vcomment("Main register bank access process.");

		vsyncprocess("clk_sys_i", "rst_n_i", {
		 vreset(0, {
			va("ack_sreg", 0);
			va("ack_in_progress", 0);
			va("rddata_reg", 0);
			resetcode
		 });

		 vposedge ({
			 vcomment("advance the ACK generator shift register");
			 va(vi("ack_sreg", MAX_ACK_LENGTH-2, 0), vi("ack_sreg", MAX_ACK_LENGTH-1, 1));
			 va(vi("ack_sreg", MAX_ACK_LENGTH-1), 0);
		
			 vif(vequal("ack_in_progress", 1), {
			 	 vif(vequal(vi("ack_sreg", 0), 1), { ackgencode; va("ack_in_progress", 0); }, preackcode);
			 }, { 
				fsmcode
			 });
			});
		});
	};		 


-- we have some RAMs in our slave?
	if(periph.ramcount > 0) then

-- the data output is muxed between RAMs and register bank. Here we generate a combinatorial mux if we don't want the output to be registered. This gives us
-- memory access time of 2 clock cycles. Otherwise the ram output is handled by the main process.
		if(not options.register_data_output) then
			local sens_list = {"rddata_reg","rwaddr_reg"};
			local mux_switch_code = {};
			local mux_code = {vswitch(vi("rwaddr_reg", address_bus_width-1, address_bus_width - address_bus_select_bits), mux_switch_code); };

			local output_mux_process = {vcomment("Data output multiplexer process"); vcombprocess(sens_list, mux_code);};
			
			 foreach_reg({TYPE_RAM}, function(reg) 
  								table.insert(sens_list, reg.full_prefix.."_rddata_int");
									
									local assign_code =  { va(vi("wb_dat_o", reg.width-1, 0), reg.full_prefix.."_rddata_int"); };
									
									if(reg.width < DATA_BUS_WIDTH)  then
										table_join(assign_code, { va(vi("wb_dat_o", DATA_BUS_WIDTH-1, reg.width), 0); });
									end
									
  								

  								table_join(mux_switch_code, { vcase(reg.select_bits, assign_code ); } );
  						end);

			table.insert(sens_list, "wb_adr_i");		

			table_join(mux_switch_code, {vcasedefault(va("wb_dat_o", "rddata_reg")); } );
			table_join(code, output_mux_process);
		end

-- now generate an address decoder for the RAMs, driving rd_i and wr_i lines.

		local sens_list = { "wb_adr_i", "rd_int", "wr_int" };
		local proc_body = { };

			 foreach_reg({TYPE_RAM}, function(reg) 
  							--	table.insert(sens_list, reg.full_prefix.."_rddata_int");
									table_join(proc_body, {vif(vequal(vi("wb_adr_i", address_bus_width-1, address_bus_width - address_bus_select_bits), reg.select_bits), {
										va(reg.full_prefix.."_rd_int", "rd_int");
										va(reg.full_prefix.."_wr_int", "wr_int");
									}, {
										va(reg.full_prefix.."_wr_int", 0);
										va(reg.full_prefix.."_rd_int", 0);
									});  });
  						end);

		table_join(code, {vcomment("Read & write lines decoder for RAMs"); vcombprocess(sens_list, proc_body); });

	else -- no RAMs in design? wire rddata_reg directly to wb_data_o
		table_join(code, {vcomment("Drive the data output bus"); va("wb_dat_o", "rddata_reg") } );
	end

  
  foreach_reg(ALL_REG_TYPES, 
              function(reg) 
                 ex_code = {}

                 if(reg.extra_code ~= nil) then
                    table_join(ex_code, {vcomment("extra code for reg/fifo/mem: "..reg.name);});
                    table_join(ex_code, reg.extra_code);

                 end

                 foreach_subfield(reg, 
                                  function(field, reg) 
                                     if (field.extra_code ~= nil) then
                                        table_join(ex_code, {vcomment(field.name); field.extra_code}); 
                                     end	
                                  end );
                 
                 if(reg.optional == nil) then
                    table_join(code, ex_code)
                 else
                    table_join(code, {vgenerate_if(vnot(vequal(reg.optional, 0)), ex_code )} ); 
                 end

							end);


	
	if(address_bus_width > 0) then
		table_join(code, { 	va("rwaddr_reg", "wb_adr_i");	});
	else
		table_join(code, { 	va("rwaddr_reg", vothers(0));	});
	end

	table_join(code, { va("wb_stall_o", vand(vnot(vi("ack_sreg", 0)), vand("wb_stb_i","wb_cyc_i")))});
	
	table_join(code, { vcomment("ACK signal generation. Just pass the LSB of ACK counter.");
										 va("wb_ack_o", vi("ack_sreg", 0));
										});

	return code;
end

