import struct

# TESTY
from samba.param import LoadParm
from samba.auth import system_session
from samba import samdb, ldb
from pprint import pprint


class OAB:
    MAX_UL_TOT_RECORDS = 16777212

    def __init__(self):
        pass

    def createFiles(self, accounts, directory):
        nAccounts = len(accounts)
        if (nAccounts == 0):
            raise Exception('Trying to create OAB files without accounts');
        elif (nAccounts  > OAB.MAX_UL_TOT_RECORDS):
            # XXX removing excessive accounts
            nAccounts = nAccounts[0:OAB.MAX_UL_TOT_RECORDS-1]

        browseFileContents = self._browseFileContents(accounts)
        print 'Browse file:'
        pprint(browseFileContents)

        rdnFileContents    = self._rdnFileContents(accounts)
        print 'RDN file:'
        pprint(rdnFileContents)


    def _browseFileContents(self, accounts):
            contents = self._browseFileHeader(accounts)
            for acc in accounts:
                record  = self._browseRecord(acc)
                contents += record

            # calculate RDN hash for put in browse file
            return contents

    def _browseFileHeader(self, accounts):
        header = bytearray(10)
        # ulVersion
        header[0] =  0xA
        header[1] =  0x0
        # ulSerial
        # TODO 2.3.3
        packedNAccounts = struct.pack('<I', len(accounts))
        header[4] = packedNAccounts[0]
        header[5] = packedNAccounts[1]
        header[6] = packedNAccounts[2]
        header[7] = packedNAccounts[3]
        return header

    def _browseRecord(self, account):
        record = bytearray(32)
        # TODO oRDN 4
        # TODO oDetails 4
        # TODO cbDetails 2
        # bDispType
        if account['type'] == 'mailuser':
            record[10] = 0x0
        elif account['type'] == 'distlist':
            record[10] = 0x1
        else:
            raise Exception("Unknow account type " + record['type'])

        # a 1b 1 (can receive rich content)
        if account['SendRichInfo']:
            record[11] = 0x80
        else:
            record[11] = 0x00
        # mailobj (7b)
        if account['type'] == 'mailuser':
            record[11] += 0x06
        elif account['type'] == 'distlist':
            record[11] += 0x08
        else:
            raise Exception("Unknow account type " + record['type'])

        # oAlias (4 bytes): A 32-bit unsigned integer that specifies the offset of the alias record in the
        # ANR Index file.

        # oLocation (4 bytes): A 32-bit unsigned integer that specifies the offset of the office location
        # record in the ANR Index file.

        # oSurname (4 bytes): A 32-bit unsigned integer that specifies the offset of the surname record
        # in the ANR Index file.
        return record

    def _rdnFileContents(self, accounts):
        contents = self._rdnHeader(accounts)

        pdn = self._rdnPdnRecords(accounts, len(contents))
        pprint(pdn)
        contents += pdn[1]

        # now we have the offset of the first RDN and we can set oRoot
        print "oRoot len(ciontnts) _> " + str(len(contents))
#        oRootPacked = struct.pack('<I', len(contents))
        oRootPacked = self._pack_uint(len(contents))
        contents[12:16]  = oRootPacked[0:4]

        oPrev = 0;
        oNextBase = len(contents)
        lastAccount = len(accounts) - 1
        for i in range(0, lastAccount +1):
            acc = accounts[i]
            if i == lastAccount:
                oNextBase = 0
            record = self._rdnRecord(acc, pdn[0], oPrev, oNextBase)
            oPrev = len(contents)
            contents += record
            oNextBase = len(contents)

        return contents


    def _rdnHeader(self, accounts):
        header = bytearray(16)
        # ulVersion
        header[0:4] = 0x0E, 0x00, 0x00, 0x00

        # ulSerial (4 bytes): A 32-bit hexadecimal string that specifies the hash of the RDN (1) values for
        #   the current set of OAB records. The value of this field is calculated as specified in section
        # TODO

        # ulTotRecs (4 bytes)
        packedNAccounts = struct.pack('<I', len(accounts))
        header[8:12] = packedNAccounts

        # oRoot (4 bytes): A 32-bit unsigned integer that specifies the offset of the root RDN2_REC
        # to be calculated and set later
        return header

        # returns the tuple (offsetByPdn, pdnRecordsByteArray)
    def _rdnPdnRecords(self, accounts, offset):
        offsetByPdn = {}
        records = bytearray();
        for acc in accounts:
            dn = acc['dn']
            rdn, pdn = dn.split(',', 1)
            if pdn in offsetByPdn:
                continue
            pdnBytes = bytearray(pdn)
            pdnBytes.append(0x00);
            offsetByPdn[pdn] = offset;
            offset += len(pdnBytes)
            records += pdnBytes

        return (offsetByPdn, records)

    def _rdnRecord(self, account, offsetByPdn, oPrev, oNextBase):
        record = bytearray(24) # min size, RDN records are variable
        rdn, pdn = account['dn'].split(',', 1)

        # XXX degenerate tree: oLT, rLT -> oPrev, oNext
        # oLT 4b
        record[0:4] = struct.pack('<I', oPrev)[0:4]
        # rLT 4b
        # iBrowse (4 bytes):
        # TODO
        # oPrev (4 bytes)
        record[12:16] = struct.pack('<I', oPrev)[0:4]
        # oNext (4 bytes)
        # set later

        # oParentDN (4 bytes)
        print rdn + ' pdn: ' + pdn + ' offset ' + str(offsetByPdn[pdn])
        record[20:24] = self._pack_uint(offsetByPdn[pdn])

        # acKey (variable):
        record +=  bytearray(rdn) + b'0'

        oNext = 0
        if (oNextBase != 0):
            oNext = oNextBase + len(record)
        # rLT
        record[4:8] = struct.pack('<I', oNext)[0:4]
        # oNext
        record[16:20] = struct.pack('<I', oNext)[0:4]

        return record

    def _pack_uint(self, uint):
        return struct.pack('<I', uint)


    def endClass():
        pass




def accountsList():
    samdb_url = '/var/lib/samba/private/sam.ldb'
    db = samdb.SamDB(url=samdb_url, session_info=system_session(), lp=LoadParm())

    accounts = []
    basedn =  db.domain_dn()
    res = db.search(base=basedn, scope=ldb.SCOPE_SUBTREE, expression="(|(objectclass=user))(objectclass=group)))")

    for entry in res:
        mailAttr =  entry.get('mail')
        if not mailAttr:
            continue

        account = {}
        account['mail'] = mailAttr.get(0)
        account['dn'] = str(entry.dn)
        account_type = ''
        for oclass in entry.get('objectclass'):
            if oclass == "user":
                account_type = 'mailuser'
                break;
            elif oclass == "group":
                account_type = 'distlist'
                break

            if account_type == '':
                # Not valid objectclass!
                continue

        account['type'] = account_type
        account['samAccountName']= entry.get('samAccountName').get(0)
        account['SendRichInfo'] = 1 # for now always on

        accounts.append(account)

    return accounts


# test code
accounts = accountsList()
pprint(accounts)
oab = OAB()
oab.createFiles(accounts, '/tmp')
