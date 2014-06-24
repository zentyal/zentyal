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
             pdn = str(pdnBytes)
             pdnByOffset[pdnOffset] = pdn

             pdnOffset += pdnLen
             begSearch = found + 1

        pprint(pdnByOffset)

        rdnPart = pdnPart[oRoot:] # DDd
        pprint (rdnPart) # DDD

        # checking using prev/next links
        # XXX degenerate tree; tree not checked
        prevLink = 0
        nextLink = oRoot


        while nextLink != 0:
            print "RDN with offset " + str(nextLink)

            oPrev = self._unpack_uint(rdnContents[nextLink+12:nextLink+16])
            self.assertTrue(oPrev < rdnContentsSize)
            self.assertTrue(oPrev == prevLink)

            oNext = self._unpack_uint(rdnContents[nextLink+16:nextLink+20])
            self.assertTrue(oNext < rdnContentsSize)

            oParentDN = self._unpack_uint(rdnContents[nextLink+20:nextLink+24])
            print 'oParentDN ' + str(oParentDN)
            self.assertTrue(oParentDN in pdnByOffset)

            found = rdnContents.find(b'0', nextLink+24)
            rdnBytes  =  rdnContents[nextLink+24:found]
            rdn = str(rdnBytes)
            print 'RDN=' + rdn

            prevLink = nextLink
            nextLink = oNext



    def test_rdn_consistence(self):
        cases = [
           bytearray(b'\x0e\x00\x00\x00\x00\x00\x00\x00\n\x00\x00\x00l\x00\x00\x00OU=\xd1\x80\xd1\x83\xd1\x81\xd0\xba\xd0\xb8,DC=zentyal-domain,DC=lan\x00zentyal-domain.lan\x00CN=Users,DC=zentyal-domain,DC=lan\x00\x00\x00\x00\x00\x90\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x90\x00\x00\x00\x10\x00\x00\x00asdvsdffv a0l\x00\x00\x00\xac\x00\x00\x00\x00\x00\x00\x00l\x00\x00\x00\xac\x00\x00\x007\x00\x00\x00u2@0\x90\x00\x00\x00\xd2\x00\x00\x00\x00\x00\x00\x00\x90\x00\x00\x00\xd2\x00\x00\x00J\x00\x00\x00Administrator0\xac\x00\x00\x00\xf9\x00\x00\x00\x00\x00\x00\x00\xac\x00\x00\x00\xf9\x00\x00\x007\x00\x00\x00administrator@0\xd2\x00\x00\x00\x1c\x01\x00\x00\x00\x00\x00\x00\xd2\x00\x00\x00\x1c\x01\x00\x00J\x00\x00\x00sdsdsd dfg0\xf9\x00\x00\x008\x01\x00\x00\x00\x00\x00\x00\xf9\x00\x00\x008\x01\x00\x007\x00\x00\x00u1@0\x1c\x01\x00\x00V\x01\x00\x00\x00\x00\x00\x00\x1c\x01\x00\x00V\x01\x00\x00J\x00\x00\x00Guest08\x01\x00\x00u\x01\x00\x00\x00\x00\x00\x008\x01\x00\x00u\x01\x00\x007\x00\x00\x00guest@0V\x01\x00\x00\x92\x01\x00\x00\x00\x00\x00\x00V\x01\x00\x00\x92\x01\x00\x00J\x00\x00\x00a ad0u\x01\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00u\x01\x00\x00\x00\x00\x00\x007\x00\x00\x00ad@0')
          ]
        for case in cases:
            self._check_rdn_consistence(case)

    def _check_anr_consistence(self, anr_contents):
        anr_contents_size = len(anr_contents)
        nAccounts = self._unpack_uint(anr_contents[8:12])
        self.assertTrue(nAccounts > 0)


        # checking using prev/next links
        # XXX degenerate tree; tree not checked
        prevLink = 0
        nextLink = 16 # 16b headert
        while nextLink != 0:
            print "ANR with offset " + str(nextLink)

            oPrev = self._unpack_uint(anr_contents[nextLink+12:nextLink+16])
            self.assertTrue(oPrev < anr_contents_size)
            self.assertTrue(oPrev == prevLink)

            oNext = self._unpack_uint(anr_contents[nextLink+16:nextLink+20])
            self.assertTrue(oNext < anr_contents_size)

            found = anr_contents.find(b'0', nextLink+24)
            anr_bytes  =  anr_contents[nextLink+24:found]
            anr = str(anr_bytes)
            print 'ANR=' + anr

            prevLink = nextLink
            nextLink = oNext

    def test_anr_consistence(self):
        cases = [
            bytearray(b"\x0e\x00\x00\x00\x00\x00\x00\x00\x04\x00\x00\x00\x00\x00\x00\x00#\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00#\x00\x00\x00u20\x0c\x00\x00\x00\'\x00\x00\x00\x00\x00\x00\x00\x0c\x00\x00\x00\'\x00\x00\x00ibubui0\x0c\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x0c\x00\x00\x00\x00\x00\x00\x00u10\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00a0")

            ]
        for case in cases:
            self._check_anr_consistence(case)



    def _unpack_uint(self, barray):
        bstr = str(bytearray(barray[0:4]))
        return struct.unpack('<I', bstr)[0]


if __name__ == '__main__':
    unittest.main()
