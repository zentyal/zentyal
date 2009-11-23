#ifndef __VSCAN_FILETYPE_H_
#define __VSCAN_FILETYPE_H_


BOOL filetype_init (int flags, pstring exclude_list);
void filetype_close();
int filetype_skipscan(pstring fname);

#endif /* __VSCAN_FILETYPE_H_ */
