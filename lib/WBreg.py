class WBreg(object):
    
    def __init__(self, baseaddr, readfun, writefun):
        self.__read = readfun
        self.__write = writefun

        self.base = baseaddr

    def read(self, addr, mask):
        tmp = self.__read(self.base+addr)
        return self.__read_mask(tmp, mask) ;

    def write(self, addr, mask, val):
        tmp = self.__read(self.base+addr)
        tmp = self.__modify_mask(tmp, mask, val);
        self.__write(addr + self.base, tmp);

    ######################################################################
    ########################## helpers ###################################
    ######################################################################
    def __read_mask( self, value, mask ):
    #     clear all unmasked bits
        value = value & mask;
        bit = 1;
    #     right shift the value until it starts from bit 0
        while ( not (mask & bit) ): 
            bit = bit << 1;
            value = value >> 1;
        return value;
          
    
    def __modify_mask( self, previous, mask, new ):
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