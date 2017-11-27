import amc


def write( addr, val):
    print "write addr:0x%08x data:0x%08x" % (addr, val)
    return 0


def read( addr):
    print "read addr:0x%08x" % (addr)
    return 0xaabbccdd

uut=amc.Wbreg_amc(0xf0,read, write)

print "%x" % uut.p2p_0.read()
print "%x" % uut.oe_p2p_out0.read()
print "%x" % uut.oe_p2p_out0.write(3)



