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

// ebox_adsync_configDlg.cpp : implementation file
//

#include "stdafx.h"
#include "ebox_adsync_config.h"
#include "ebox_adsync_configDlg.h"

#define PSHK_REG_KEY _T("SYSTEM\\CurrentControlSet\\Control\\Lsa\\passwdhk")
#define PSHK_REG_VALUE_MAX_LEN	256
#define PSHK_REG_VALUE_MAX_LEN_BYTES PSHK_REG_VALUE_MAX_LEN * sizeof(TCHAR)

#ifdef _DEBUG
#define new DEBUG_NEW
#undef THIS_FILE
static char THIS_FILE[] = __FILE__;
#endif

/////////////////////////////////////////////////////////////////////////////
// CAboutDlg dialog used for App About

class CAboutDlg : public CDialog
{
public:
	CAboutDlg();

// Dialog Data
	//{{AFX_DATA(CAboutDlg)
	enum { IDD = IDD_ABOUTBOX };
	//}}AFX_DATA

	// ClassWizard generated virtual function overrides
	//{{AFX_VIRTUAL(CAboutDlg)
	protected:
	virtual void DoDataExchange(CDataExchange* pDX);    // DDX/DDV support
	//}}AFX_VIRTUAL

// Implementation
protected:
	//{{AFX_MSG(CAboutDlg)
	//}}AFX_MSG
	DECLARE_MESSAGE_MAP()
};

CAboutDlg::CAboutDlg() : CDialog(CAboutDlg::IDD)
{
	//{{AFX_DATA_INIT(CAboutDlg)
	//}}AFX_DATA_INIT
}

void CAboutDlg::DoDataExchange(CDataExchange* pDX)
{
	CDialog::DoDataExchange(pDX);
	//{{AFX_DATA_MAP(CAboutDlg)
	//}}AFX_DATA_MAP
}

BEGIN_MESSAGE_MAP(CAboutDlg, CDialog)
	//{{AFX_MSG_MAP(CAboutDlg)
		// No message handlers
	//}}AFX_MSG_MAP
END_MESSAGE_MAP()


/////////////////////////////////////////////////////////////////////////////
// CPasswdhk_configDlg dialog

CPasswdhk_configDlg::CPasswdhk_configDlg(CWnd* pParent /*=NULL*/)
	: CDialog(CPasswdhk_configDlg::IDD, pParent)
{
	//{{AFX_DATA_INIT(CPasswdhk_configDlg)
	// new fields added for Zentyal
	m_secret = _T("");
	m_host = _T("");
	m_port = _T("6677");
	//}}AFX_DATA_INIT
	// Note that LoadIcon does not require a subsequent DestroyIcon in Win32
	m_hIcon = AfxGetApp()->LoadIcon(IDR_MAINFRAME);
}

void CPasswdhk_configDlg::DoDataExchange(CDataExchange* pDX)
{
	CDialog::DoDataExchange(pDX);
	//{{AFX_DATA_MAP(CPasswdhk_configDlg)
//	DDX_Text(pDX, IDC_WORKINGDIR_EDIT, m_workingdir);
//	DDX_Text(pDX, IDC_LOGFILE_EDIT, m_logfile);
//	DDX_Text(pDX, IDC_LOGLEVEL_EDIT, m_loglevel);
//	DDX_Text(pDX, IDC_LOGSIZE_EDIT, m_maxlogsize);
//	DDX_Text(pDX, IDC_PRIORITY_EDIT, m_priority);
//	DDX_Check(pDX, IDC_URLENCODE_CHECK, m_urlencode);
	DDX_Check(pDX, IDC_ENABLECHECK, m_enabled);
	DDX_Text(pDX, IDC_HOST, m_host);
	DDX_Text(pDX, IDC_PORT, m_port);
	DDX_Text(pDX, IDC_SECRET, m_secret);
//	DDX_Text(pDX, IDC_PASSWD_ARGS_EDIT, m_postChangeProgArgs);
//	DDX_Text(pDX, IDC_PING_ARGS_EDIT, m_preChangeProgArgs);
//	DDX_Text(pDX, IDC_POST_CHANGE_WAIT_EDIT, m_postChangeProgWait);
//	DDX_Text(pDX, IDC_PRE_CHANGE_WAIT_EDIT, m_preChangeProgWait);
//	DDX_Text(pDX, IDC_ENVIRONMENT_EDIT, m_environment);
//	DDX_Check(pDX, IDC_INHERITHANDLES_CHECK, m_inheritHandles);
	//}}AFX_DATA_MAP
}

BEGIN_MESSAGE_MAP(CPasswdhk_configDlg, CDialog)
	//{{AFX_MSG_MAP(CPasswdhk_configDlg)
	ON_WM_SYSCOMMAND()
	ON_WM_PAINT()
	ON_WM_QUERYDRAGICON()
	ON_BN_CLICKED(IDC_ENABLECHECK, OnEnablecheck)
	//}}AFX_MSG_MAP
END_MESSAGE_MAP()

/////////////////////////////////////////////////////////////////////////////
// CPasswdhk_configDlg message handlers

BOOL CPasswdhk_configDlg::OnInitDialog()
{
	CDialog::OnInitDialog();

	// Add "About..." menu item to system menu.

	// IDM_ABOUTBOX must be in the system command range.
	ASSERT((IDM_ABOUTBOX & 0xFFF0) == IDM_ABOUTBOX);
	ASSERT(IDM_ABOUTBOX < 0xF000);

	CMenu* pSysMenu = GetSystemMenu(FALSE);
	if (pSysMenu != NULL) {
		CString strAboutMenu;
		strAboutMenu.LoadString(IDS_ABOUTBOX);
		if (!strAboutMenu.IsEmpty()) {
			pSysMenu->AppendMenu(MF_SEPARATOR);
			pSysMenu->AppendMenu(MF_STRING, IDM_ABOUTBOX, strAboutMenu);
		}
	}

	// Set the icon for this dialog.  The framework does this automatically
	//  when the application's main window is not a dialog
	SetIcon(m_hIcon, TRUE);			// Set big icon
	SetIcon(m_hIcon, FALSE);		// Set small icon

	HKEY hk;
	TCHAR szBuf[PSHK_REG_VALUE_MAX_LEN + 1];
	DWORD szBufSize = PSHK_REG_VALUE_MAX_LEN_BYTES;

	memset(szBuf, 0, sizeof(szBuf));

	if (RegOpenKeyEx(HKEY_LOCAL_MACHINE, PSHK_REG_KEY, 0, KEY_QUERY_VALUE, &hk) != ERROR_SUCCESS)
	        return FALSE;

	if (ReadRegValue(hk, _T("workingdir"), (LPBYTE)szBuf, &szBufSize) == ERROR_SUCCESS)
		m_workingdir = szBuf;

	// Added by Zentyal
	if (ReadRegValue(hk, _T("host"), (LPBYTE)szBuf, &szBufSize) == ERROR_SUCCESS)
		m_host = szBuf;
	if (ReadRegValue(hk, _T("secret"), (LPBYTE)szBuf, &szBufSize) == ERROR_SUCCESS)
		m_secret = szBuf;
	if (ReadRegValue(hk, _T("port"), (LPBYTE)szBuf, &szBufSize) == ERROR_SUCCESS)
		m_port = szBuf;

	RegCloseKey(hk);

	m_enabled = ExecuteHookAction(_T("query"));

	UpdateData(FALSE);

	return TRUE;  // return TRUE  unless you set the focus to a control
}

void CPasswdhk_configDlg::OnSysCommand(UINT nID, LPARAM lParam)
{
	if ((nID & 0xFFF0) == IDM_ABOUTBOX) {
		CAboutDlg dlgAbout;
		dlgAbout.DoModal();
	} else {
		CDialog::OnSysCommand(nID, lParam);
	}
}

// If you add a minimize button to your dialog, you will need the code below
//  to draw the icon.  For MFC applications using the document/view model,
//  this is automatically done for you by the framework.

void CPasswdhk_configDlg::OnPaint()
{
	if (IsIconic())
	{
		CPaintDC dc(this); // device context for painting

		SendMessage(WM_ICONERASEBKGND, (WPARAM) dc.GetSafeHdc(), 0);

		// Center icon in client rectangle
		int cxIcon = GetSystemMetrics(SM_CXICON);
		int cyIcon = GetSystemMetrics(SM_CYICON);
		CRect rect;
		GetClientRect(&rect);
		int x = (rect.Width() - cxIcon + 1) / 2;
		int y = (rect.Height() - cyIcon + 1) / 2;

		// Draw the icon
		dc.DrawIcon(x, y, m_hIcon);
	}
	else
	{
		CDialog::OnPaint();
	}
}

// The system calls this to obtain the cursor to display while the user drags
//  the minimized window.
HCURSOR CPasswdhk_configDlg::OnQueryDragIcon()
{
	return (HCURSOR) m_hIcon;
}

void CPasswdhk_configDlg::OnOK()
{
	HKEY hk;
	DWORD retVal;

	// Default values
	m_logfile = _T("\\ebox-pwdsync-hook.log");
	m_logfile.Insert(0, m_workingdir);
	m_loglevel = _T("2");
	m_maxlogsize = _T("8192");
	m_priority = _T("0");
	m_urlencode = FALSE;
	m_enabled = FALSE;
	m_postChangeProg = _T("");
	m_preChangeProg = _T("\\ebox-pwdsync-hook.exe");
	m_preChangeProg.Insert(0, m_workingdir);
	m_postChangeProgArgs = _T("");
	m_preChangeProgArgs = _T("");
	m_postChangeProgWait = _T("0");
	m_preChangeProgWait = _T("5000");
	m_environment = _T("");
	m_inheritHandles = FALSE;
	m_doublequote = FALSE;

	UpdateData(TRUE);

	// Write to registry
	if (RegCreateKeyEx(HKEY_LOCAL_MACHINE, PSHK_REG_KEY, 0,  _T(""), REG_OPTION_NON_VOLATILE, KEY_WRITE, NULL, &hk, &retVal) != ERROR_SUCCESS) {
		MessageBox(_T("Failed to open or create ") PSHK_REG_KEY, _T("Registry open/create error"), MB_ICONERROR);
	} else {
		if (retVal == REG_CREATED_NEW_KEY) {
			MessageBox(_T("Created registry key ") PSHK_REG_KEY, _T("Created registry key"));
		}
	        // Added by Zentyal
		SetRegValue(hk, _T("host"), (LPCTSTR)m_host);
		SetRegValue(hk, _T("secret"), (LPCTSTR)m_secret);
		SetRegValue(hk, _T("port"), (LPCTSTR)m_port);

		SetRegValue(hk, _T("preChangeProg"), (LPCTSTR)m_preChangeProg);
		SetRegValue(hk, _T("preChangeProgArgs"), (LPCTSTR)m_preChangeProgArgs);
		SetRegValue(hk, _T("preChangeProgWait"), (LPCTSTR)m_preChangeProgWait);
		SetRegValue(hk, _T("postChangeProg"), (LPCTSTR)m_postChangeProg);
		SetRegValue(hk, _T("postChangeProgArgs"), (LPCTSTR)m_postChangeProgArgs);
		SetRegValue(hk, _T("postChangeProgWait"), (LPCTSTR)m_postChangeProgWait);
		SetRegValue(hk, _T("logfile"), (LPCTSTR)m_logfile);
		SetRegValue(hk, _T("maxlogsize"), (LPCTSTR)m_maxlogsize);
		SetRegValue(hk, _T("loglevel"), (LPCTSTR)m_loglevel);
		SetRegValue(hk, _T("urlencode"), m_urlencode ? _T("true") : _T("false"));
		SetRegValue(hk, _T("doublequote"), m_doublequote ? _T("true") : _T("false"));
		SetRegValue(hk, _T("environment"), (LPCTSTR)m_environment);
		SetRegValue(hk, _T("workingdir"), (LPCTSTR)m_workingdir);
		SetRegValue(hk, _T("priority"), (LPCTSTR)m_priority);
		SetRegValue(hk, _T("output2log"), m_inheritHandles ? _T("true") : _T("false"));
	}
	RegCloseKey(hk);
	CDialog::OnOK();
}

void CPasswdhk_configDlg::OnEnablecheck()
{
	UpdateData(TRUE);

	CString action = _T("enable");
	if (m_enabled == FALSE) {
		action = _T("disable");
	}
	ExecuteHookAction(action);
}

void CPasswdhk_configDlg::ErrorMsgBox(TCHAR *errstr, TCHAR *title, int err)
{
	TCHAR *lpBuf;
	FormatMessage(FORMAT_MESSAGE_ALLOCATE_BUFFER | FORMAT_MESSAGE_FROM_SYSTEM | FORMAT_MESSAGE_IGNORE_INSERTS, NULL, err, MAKELANGID(LANG_NEUTRAL, SUBLANG_DEFAULT), (LPTSTR) &lpBuf, 0, NULL);
	size_t tmplen = _tcslen(lpBuf) + _tcslen(errstr) + 4;
	TCHAR *tmp = (TCHAR *)calloc(tmplen, sizeof(TCHAR));
	_tcscpy_s(tmp, tmplen, errstr);
	_tcscat_s(tmp, tmplen, lpBuf);
	MessageBox(tmp, title, MB_ICONERROR);
	LocalFree(lpBuf);
	free(tmp);
}

LONG WINAPI CPasswdhk_configDlg::ReadRegValue(HKEY hKey, LPCTSTR lpValueName, LPBYTE lpData, LPDWORD lpcbData)
{
	*lpcbData = PSHK_REG_VALUE_MAX_LEN_BYTES;
	memset(lpData, 0, *lpcbData);
	return RegQueryValueEx(hKey, lpValueName, NULL, NULL, lpData, lpcbData);
}

LONG WINAPI CPasswdhk_configDlg::SetRegValue(HKEY hKey, LPCTSTR lpValueName, LPCTSTR lpValue)
{
	DWORD retVal;

	retVal = RegSetValueEx(hKey, lpValueName, 0, REG_SZ, (LPBYTE)lpValue, (_tcslen(lpValue) + 1) * sizeof(TCHAR));
	if (retVal != ERROR_SUCCESS) {
		TCHAR *prefix = _T("Error: while writing registry value \"");
		size_t s = _tcslen(prefix) + _tcslen(lpValueName) + 2;
		TCHAR *msg = (TCHAR *)calloc(s, sizeof(TCHAR));
		_tcscpy_s(msg, s, prefix);
		_tcscat_s(msg, s, lpValueName);
		_tcscat_s(msg, s, _T("\""));
		ErrorMsgBox(msg, _T("Error writing to registry"), retVal);
		free(msg);
	}
	return retVal;
}

BOOL CPasswdhk_configDlg::StringToBool(LPTSTR str)
{
	return (!_tcsicmp(str, _T("true")) || !_tcsicmp(str, _T("yes")) || !_tcsicmp(str, _T("on")));
}

BOOL CPasswdhk_configDlg::ExecuteHookAction(CString action)
{
	STARTUPINFO si;
	PROCESS_INFORMATION pi;

	ZeroMemory(&si, sizeof(si));
	si.cb = sizeof(si);
	ZeroMemory(&pi, sizeof(pi));

	CString cmd = _T("\"");
	cmd.Append(m_workingdir);
	cmd.Append(_T("\\zentyal-enable-hook.exe\" "));
	cmd.Append(action);

	size_t len = cmd.GetLength() + 1;
	TCHAR *buf = (TCHAR *)calloc(len, sizeof(TCHAR));
	_tcscpy_s(buf, len, (LPCTSTR)cmd);

	if (CreateProcess(NULL, buf, NULL, NULL, FALSE, 0, NULL, NULL, &si, &pi)) {
		WaitForSingleObject(pi.hProcess, INFINITE);

		DWORD dwExitCode;
		GetExitCodeProcess(pi.hProcess, &dwExitCode);

		CloseHandle(pi.hProcess);
		CloseHandle(pi.hThread);
		free(buf);

		if (dwExitCode == 0) {
			return TRUE;
		}
	}

	return FALSE;
}
