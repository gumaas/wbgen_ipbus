class WBreg(object):
    
    def __init__(self, baseaddr, readfun, writefun):
        self.iface_read = readfun
        self.iface_write = writefun

        self.base = baseaddr


    ######################################################################
    ########################## helpers ###################################
    ######################################################################
    def read_mask( self, value, mask ):
    #     clear all unmasked bits
        value = value & mask;
        bit = 1;
    #     right shift the value until it starts from bit 0
        while ( not (mask & bit) ): 
            bit = bit << 1;
            value = value >> 1;
        return value;
          
    
    def modify_mask( self, previous, mask, new ):
        bit = 1;
    #     shift new value to align with mask
        while ( not (mask & bit) ): 
            bit = bit << 1;
            new = new << 1;
    #     make sure that new value doesn't exceed mask
        new = new & mask;
    #     clear masked bits in previous value
        previous = previous & (~mask);
    #     bit-or previous and new values
        new = new | previous;
        return new;


class WBReadReg(WBreg):
    
    def __init__(self, offset, mask, baseaddr, readfun, writefun):
        super(WBReadReg, self).__init__(baseaddr, readfun, writefun)
        self.addr = self.base+offset
        self.mask = mask

    def read(self):
        tmp = self.iface_read(self.addr)
        return self.read_mask(tmp, self.mask) ;


class WBWriteReg(WBreg):
    
    def __init__(self, offset, baseaddr, readfun, writefun):
        super(WBWriteReg, self).__init__(baseaddr, readfun, writefun)
        self.addr = self.base+offset


    def write(self, data):
        return self.iface_write(self.addr, data)



class WBReadWriteReg(WBreg):
    
    def __init__(self, offset, mask, baseaddr, readfun, writefun):
        super(WBReadWriteReg, self).__init__(baseaddr, readfun, writefun)
        self.addr = self.base+offset
        self.mask = mask

    def read(self):
        tmp = self.iface_read(self.addr)
        return self.read_mask(tmp, self.mask) ;

    def write(self, val):
        tmp = self.iface_read(self.addr)
        tmp = self.modify_mask(tmp, self.mask, val);
        return self.iface_write(self.addr, tmp);
        