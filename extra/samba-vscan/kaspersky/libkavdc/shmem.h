// Copyright (c) 2002, Kaspersky Lab.
// All rights reserved.
//       
// Redistribution  and  use  in  source  and  binary  forms,  with  or  without
// modification, are permitted provided that the following conditions are met:
// 		  
//     - Redistributions of source code must retain the above copyright notice,
//       this list of conditions and the following disclaimer. 
//     - Redistributions in binary form  must  reproduce  the  above  copyright
//       notice, this list of conditions  and  the  following disclaimer in the
//       documentation and/or other materials provided with the distribution. 
//     - Neither  the  name  of  the  Kaspersky  Lab.  nor  the  names  of  its
//       contributors may be used to endorse or promote  products  derived from
//       this software without specific prior written permission. 
// 									
// THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND  CONTRIBUTORS "AS IS"
// AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT  LIMITED  TO,  THE
// IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A  PARTICULAR  PURPOSE
// ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT  OWNER  OR  CONTRIBUTORS  BE
// LIABLE  FOR  ANY   DIRECT,  INDIRECT,  INCIDENTAL,  SPECIAL,  EXEMPLARY,  OR
// CONSEQUENTIAL  DAMAGES  (INCLUDING,  BUT  NOT  LIMITED  TO,  PROCUREMENT  OF
// SUBSTITUTE GOODS OR SERVICES; LOSS OF USE,  DATA,  OR PROFITS;  OR  BUSINESS
// INTERRUPTION) HOWEVER CAUSED AND ON ANY  THEORY  OF  LIABILITY,  WHETHER  IN
// CONTRACT, STRICT LIABILITY, OR  TORT  (INCLUDING  NEGLIGENCE  OR  OTHERWISE)
// ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED  OF  THE
// POSSIBILITY OF SUCH DAMAGE.

#ifndef __SHMEM_H__
#define __SHMEM_H__

typedef unsigned long ULONG;


#include <sys/types.h>
#include <sys/ipc.h>
#include <sys/shm.h>

#define FL_USESHMEM    0x01
#define FL_DOUNTUSESEM 0x02
#define FL_GETVERSION  0x04

#define PERM 0666

//data struct in shared memory
typedef struct mem_param
 {
  char IdS[16];
  ULONG ShMSize;
  key_t ShMKey;
  ULONG flags;
 } MemParam;

typedef struct mem_for_use
 {
  MemParam params;
  char buf[4];
 } MemForUse;

#define MemAlignment         0x1000  //4096

#endif

