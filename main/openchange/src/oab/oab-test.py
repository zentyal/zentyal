import unittest
import struct
from pprint import pprint

import sys
sys.path.append('.')

class TestOAB(unittest.TestCase):
    def _check_rdn_consistence(self, rdnContents):
        rdnContentsSize = len(rdnContents)

        nAccounts = struct.unpack('<I', rdnContents[8:12])
        self.assertTrue(nAccounts > 0)

        print 'rdnContents:'
        pprint (rdnContents)

 #       print 'rdnContents[12:16] -> '
 #       pprint(rdnContents[12:16])

        # DDD
        oRootBytes = str(bytearray(rdnContents[12:16]))
        print 'oRootBytes=' + str(type(oRootBytes)) + ' -> '
        pprint(oRootBytes)
        # DDD

        oRoot = self._unpack_uint(rdnContents[12:16])
        print 'oRoot= ' + str(type(oRoot)) + ' -> ' + str(oRoot) # DDD
        self.assertTrue(oRoot > 16) # always will be more that 18(size header)



        pdnPart = rdnContents[16:oRoot]
        self.assertTrue(len(pdnPart) > 0)

        pdnByOffset = {}
        begSearch = 0
        pdnOffset = 16
        while begSearch < len(pdnPart):
             found = pdnPart.find(b'\x00', begSearch)
             if found == -1:
                 self.assertTrue(False, msg='Not NUL byte find in pdn search beginning at ' + begSearch)
                 break
             pdnBytes = pdnPart[begSearch:found] # we not use found +1 bz we are not interested in NUL byte
             pdnLen   =  len(pdnBytes) + 1 # +1 -> NUL
             pdnOffset += pdnLen
             pdn = str(pdnBytes)
             pdnByOffset[pdnOffset] = pdn

             begSearch = found + 1

        pprint(pdnByOffset)

        rdnPart = pdnPart[oRoot:]
        # checking using prev/next links
        # XXX degenerate tree; tree not checked
        prevLink = 0
        nextLink = oRoot
        while nextLink != 0:


            oPrev = self._unpack_uint(rdnPart[nextLink+12:nextLink+16])
            self.assertTrue(oPrev < rdnContentsSize)
            self.assertTrue(oPrev == prevLink)

            oNext = self._unpack_uint(rdnPart[nextLink+16:nextLink+20])
            self.assertTrue(oNext < rdnContentsSize)

            oParentDN = sef._unpack_uint(rdnPart[nextLink+20:nextLink+24])
            self.assertTrue(oParentDN in pdnByOffset)

            prevLink = nextLink
            nextLink = oNext



    def test_rdn_consistence(self):
        cases = [
          bytearray(b'\x0e\x00\x00\x00\x00\x00\x00\x00\x05\x00\x00\x00Y\x00\x00\x00OU=\xd1\x80\xd1\x83\xd1\x81\xd0\xba\xd0\xb8,DC=zentyal-domain,DC=lan\x00CN=Users,DC=zentyal-domain,DC=lan\x00\x00\x00\x00\x00\x80\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x80\x00\x00\x00\x10\x00\x00\x00CN=asdvsdffv a0Y\x00\x00\x00\xa9\x00\x00\x00\x00\x00\x00\x00Y\x00\x00\x00\xa9\x00\x00\x007\x00\x00\x00CN=Administrator0\x80\x00\x00\x00\xcf\x00\x00\x00\x00\x00\x00\x00\x80\x00\x00\x00\xcf\x00\x00\x007\x00\x00\x00CN=sdsdsd dfg0\xa9\x00\x00\x00\xf0\x00\x00\x00\x00\x00\x00\x00\xa9\x00\x00\x00\xf0\x00\x00\x007\x00\x00\x00CN=Guest0\xcf\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\xcf\x00\x00\x00\x00\x00\x00\x007\x00\x00\x00CN=a ad0')
          ]
        for case in cases:
            self._check_rdn_consistence(case)

    def _unpack_uint(self, barray):
        bstr = str(bytearray(barray[0:4]))
        return struct.unpack('<I', bstr)[0]


if __name__ == '__main__':
    unittest.main()
