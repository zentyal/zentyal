// ebox_adsync_config.h : main header file for the PASSWDHK_CONFIG application
//

#if !defined(AFX_PASSWDHK_CONFIG_H__13D9CA82_4724_4678_BD32_C948919DD403__INCLUDED_)
#define AFX_PASSWDHK_CONFIG_H__13D9CA82_4724_4678_BD32_C948919DD403__INCLUDED_

#if _MSC_VER > 1000
#pragma once
#endif // _MSC_VER > 1000

#ifndef __AFXWIN_H__
	#error include 'stdafx.h' before including this file for PCH
#endif

#include "resource.h"		// main symbols

/////////////////////////////////////////////////////////////////////////////
// CPasswdhk_configApp:
// See ebox_adsync_config.cpp for the implementation of this class
//

class CPasswdhk_configApp : public CWinApp
{
public:
	CPasswdhk_configApp();

// Overrides
	// ClassWizard generated virtual function overrides
	//{{AFX_VIRTUAL(CPasswdhk_configApp)
	public:
	virtual BOOL InitInstance();
	//}}AFX_VIRTUAL

// Implementation

	//{{AFX_MSG(CPasswdhk_configApp)
		// NOTE - the ClassWizard will add and remove member functions here.
		//    DO NOT EDIT what you see in these blocks of generated code !
	//}}AFX_MSG
	DECLARE_MESSAGE_MAP()
};


/////////////////////////////////////////////////////////////////////////////

//{{AFX_INSERT_LOCATION}}
// Microsoft Visual C++ will insert additional declarations immediately before the previous line.

#endif // !defined(AFX_PASSWDHK_CONFIG_H__13D9CA82_4724_4678_BD32_C948919DD403__INCLUDED_)
