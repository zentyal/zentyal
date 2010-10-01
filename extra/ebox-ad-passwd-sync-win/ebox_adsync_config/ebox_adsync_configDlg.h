/********************************************************************
** This file is part of 'AcctSync' package.
**
**  AcctSync is free software; you can redistribute it and/or modify
**  it under the terms of the Lesser GNU General Public License as
**  published by the Free Software Foundation; either version 2
**  of the License, or (at your option) any later version.
**
**  AcctSync is distributed in the hope that it will be useful,
**  but WITHOUT ANY WARRANTY; without even the implied warranty of
**  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
**  Lesser GNU General Public License for more details.
**
**  You should have received a copy of the Lesser GNU General Public
**  License along with AcctSync; if not, write to the
**	Free Software Foundation, Inc.,
**	59 Temple Place, Suite 330,
**	Boston, MA  02111-1307
**	USA
**
** +AcctSync was originally Written by.
**  Kervin Pierre
**  Information Technology Department
**  Florida Tech
**  MAR, 2002
**
** +Modified by.
**  Brian Clayton
**  Information Technology Services
**  Clark University
**  MAR, 2008
**
** Redistributed under the terms of the LGPL
** license.  See LICENSE.txt file included in
** this package for details.
**
********************************************************************/

// ebox_adsync_configDlg.h : header file
//

#if !defined(AFX_PASSWDHK_CONFIGDLG_H__5A82D565_0667_453B_B188_81EDFDC06C6B__INCLUDED_)
#define AFX_PASSWDHK_CONFIGDLG_H__5A82D565_0667_453B_B188_81EDFDC06C6B__INCLUDED_

#if _MSC_VER > 1000
#pragma once
#endif // _MSC_VER > 1000

/////////////////////////////////////////////////////////////////////////////
// CPasswdhk_configDlg dialog

class CPasswdhk_configDlg : public CDialog
{
// Construction
public:
	CPasswdhk_configDlg(CWnd* pParent = NULL);	// standard constructor

// Dialog Data
	//{{AFX_DATA(CPasswdhk_configDlg)
	enum { IDD = IDD_PASSWDHK_CONFIG_DIALOG };
	CString	m_host;
	CString	m_port;
	CString	m_secret;
	CString	m_workingdir;
	CString	m_logfile;
	CString	m_loglevel;
	CString m_maxlogsize;
	CString	m_priority;
	BOOL	m_urlencode;
	BOOL	m_enabled;
	CString	m_postChangeProg;
	CString m_preChangeProg;
	CString	m_postChangeProgArgs;
	CString	m_preChangeProgArgs;
	CString	m_postChangeProgWait;
	CString	m_preChangeProgWait;
	CString	m_environment;
	BOOL	m_inheritHandles;
	BOOL	m_doublequote;
	//}}AFX_DATA

	// ClassWizard generated virtual function overrides
	//{{AFX_VIRTUAL(CPasswdhk_configDlg)
	protected:
	virtual void DoDataExchange(CDataExchange* pDX);	// DDX/DDV support
	//}}AFX_VIRTUAL

// Implementation
protected:
	HICON m_hIcon;
	LONG WINAPI SetRegValue(HKEY hKey, LPCTSTR lpValueName, LPCTSTR lpValue);
	LONG WINAPI ReadRegValue(HKEY hKey, LPCTSTR lpValueName, LPBYTE lpData, LPDWORD lpcbData);
	BOOL StringToBool(LPTSTR str);
	BOOL ExecuteHookAction(CString action);

	// Generated message map functions
	//{{AFX_MSG(CPasswdhk_configDlg)
	virtual BOOL OnInitDialog();
	afx_msg void OnSysCommand(UINT nID, LPARAM lParam);
	afx_msg void OnPaint();
	afx_msg HCURSOR OnQueryDragIcon();
	virtual void OnOK();
	afx_msg void OnEnablecheck();
	afx_msg void ErrorMsgBox(TCHAR *errstr, TCHAR *title, int err);
	//}}AFX_MSG
	DECLARE_MESSAGE_MAP()
};

//{{AFX_INSERT_LOCATION}}
// Microsoft Visual C++ will insert additional declarations immediately before the previous line.

#endif // !defined(AFX_PASSWDHK_CONFIGDLG_H__5A82D565_0667_453B_B188_81EDFDC06C6B__INCLUDED_)
