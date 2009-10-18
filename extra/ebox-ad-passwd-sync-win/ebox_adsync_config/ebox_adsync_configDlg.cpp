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

#define PSHK_REG_KEY "SYSTEM\\CurrentControlSet\\Control\\Lsa\\ebox-adsync"
#define PSHK_REG_VALUE_MAX_LEN	256

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

void pshk_trim( char *str )
{
	//Remove leading...
	for( unsigned int i=0; i<strlen(str)-1; i++ )
		if(str[i]==' ')
		{
			strcpy(&str[i], &str[i+1]);
			str[strlen(str)+1]=0;
		}
		else break;

	//...and trailing spaces
	for(i=strlen(str)-1; i>=0; i-- )
		if(str[i]==' ')
			str[i]=0;
		else break;

	//...and consecutive spaces
	for(i=1;i<strlen(str)-1;i++)
		if(str[i]==' ' && str[i-1]==' ')
		{
			strcpy(&str[i-1], &str[i]);
			str[strlen(str)+1]=0;
		}
}

/////////////////////////////////////////////////////////////////////////////
// CPasswdhk_configDlg dialog

CPasswdhk_configDlg::CPasswdhk_configDlg(CWnd* pParent /*=NULL*/)
	: CDialog(CPasswdhk_configDlg::IDD, pParent)
{
	// Get the installation path for appending it if it's passed
	// as a commandline argument
	CString instPath;
	if (__argc > 1) {
		instPath = __argv[1];
	}
	//{{AFX_DATA_INIT(CPasswdhk_configDlg)
	m_workingdir = instPath;
	m_logfile = _T("\\ebox-pwdsync-hook.log");
	m_logfile.Insert(0, instPath);
	m_loglevel = _T("3");
	m_maxlogsize = _T("8192");
	m_priority = _T("0");
	m_urlencode = TRUE;
	m_enabled = FALSE;
	m_postChangeProg = _T("");
	m_preChangeProg = _T("\\ebox-pwdsync-hook.exe");
	m_preChangeProg.Insert(0, instPath);
	m_postChangeProgArgs = _T("");
	m_preChangeProgArgs = _T("");
	m_postChangeProgWait = _T("0");
	m_preChangeProgWait = _T("5000");
	m_environment = _T("");
	m_inheritHandles = FALSE;
	// new fields added for eBox
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
	if (pSysMenu != NULL)
	{
		CString strAboutMenu;
		strAboutMenu.LoadString(IDS_ABOUTBOX);
		if (!strAboutMenu.IsEmpty())
		{
			pSysMenu->AppendMenu(MF_SEPARATOR);
			pSysMenu->AppendMenu(MF_STRING, IDM_ABOUTBOX, strAboutMenu);
		}
	}

	// Set the icon for this dialog.  The framework does this automatically
	//  when the application's main window is not a dialog
	SetIcon(m_hIcon, TRUE);			// Set big icon
	SetIcon(m_hIcon, FALSE);		// Set small icon

	// TODO: Add extra initialization here
	HKEY hk, hk2;
	char szBuf[PSHK_REG_VALUE_MAX_LEN+1];
	DWORD szBufSize = PSHK_REG_VALUE_MAX_LEN;
	char szBuf2[PSHK_REG_VALUE_MAX_LEN+1];
	DWORD szBufSize2 = PSHK_REG_VALUE_MAX_LEN;
	DWORD readRetVal;

	memset(szBuf, 0, sizeof(szBuf));

	if( RegOpenKeyEx(HKEY_LOCAL_MACHINE, PSHK_REG_KEY,
		0, KEY_QUERY_VALUE, &hk) != ERROR_SUCCESS )
	{
        return FALSE;
	}

	/* Get the host */
	readRetVal = RegQueryValueEx(hk, "host", NULL, NULL, (LPBYTE)szBuf, &szBufSize);
	if( readRetVal == ERROR_SUCCESS )
	{
		m_host = _T("");
		m_host.Insert(0, szBuf);
	}
	memset(szBuf, 0, sizeof(szBuf));
	szBufSize = PSHK_REG_VALUE_MAX_LEN;

	/* Get the secret */
	readRetVal = RegQueryValueEx(hk, "secret", NULL, NULL, (LPBYTE)szBuf, &szBufSize);
	if( readRetVal == ERROR_SUCCESS )
	{
		m_secret = _T("");
		m_secret.Insert(0, szBuf);
	}
	memset(szBuf, 0, sizeof(szBuf));
	szBufSize = PSHK_REG_VALUE_MAX_LEN;

	/* Get the port */
	readRetVal = RegQueryValueEx(hk, "port", NULL, NULL, (LPBYTE)szBuf, &szBufSize);
	if( readRetVal == ERROR_SUCCESS )
	{
		m_port = _T("");
		m_port.Insert(0, szBuf);
	}
	memset(szBuf, 0, sizeof(szBuf));
	szBufSize = PSHK_REG_VALUE_MAX_LEN;

	/* Get the log level */
	readRetVal
		= RegQueryValueEx( hk,"loglevel", NULL, NULL, (LPBYTE)szBuf, &szBufSize);
	if( readRetVal == ERROR_SUCCESS )
	{
		m_loglevel = _T("");
		m_loglevel.Insert(0, szBuf);
	}
	memset(szBuf, 0, sizeof(szBuf));
	szBufSize = PSHK_REG_VALUE_MAX_LEN;

	/* Get the priority */
	readRetVal
		= RegQueryValueEx( hk,"priority", NULL, NULL, (LPBYTE)szBuf, &szBufSize);
	if( readRetVal == ERROR_SUCCESS )
	{
		m_priority = _T("");
		m_priority.Insert(0, szBuf);
	}
	memset(szBuf, 0, sizeof(szBuf));
	szBufSize = PSHK_REG_VALUE_MAX_LEN;

	/* Get the pre-change program wait time */
	readRetVal
		= RegQueryValueEx( hk,"preChangeProgWait", NULL, NULL, (LPBYTE)szBuf, &szBufSize);
	if( readRetVal == ERROR_SUCCESS )
	{
		m_preChangeProgWait = _T("");
		m_preChangeProgWait.Insert(0, szBuf);
	}
	memset(szBuf, 0, sizeof(szBuf));
	szBufSize = PSHK_REG_VALUE_MAX_LEN;

	/* Get the post-change program wait time */
	readRetVal
		= RegQueryValueEx( hk,"postChangeProgWait", NULL, NULL, (LPBYTE)szBuf, &szBufSize);
	if( readRetVal == ERROR_SUCCESS )
	{
		m_postChangeProgWait = _T("");
		m_postChangeProgWait.Insert(0, szBuf);
	}
	memset(szBuf, 0, sizeof(szBuf));
	szBufSize = PSHK_REG_VALUE_MAX_LEN;

	/* Get the working directory */
	readRetVal = RegQueryValueEx(hk, "workingdir", NULL, NULL, (LPBYTE)szBuf, &szBufSize);
	if( readRetVal == ERROR_SUCCESS )
	{
		m_workingdir = _T("");
		m_workingdir.Insert(0, szBuf);
	}
	memset(szBuf, 0, sizeof(szBuf));
	szBufSize = PSHK_REG_VALUE_MAX_LEN;


	/* Get the log file */
	readRetVal = RegQueryValueEx(hk, "logfile", NULL, NULL, (LPBYTE)szBuf, &szBufSize);
	if( readRetVal == ERROR_SUCCESS )
	{
		m_logfile.Insert(0, szBuf);
	}
	memset(szBuf, 0, sizeof(szBuf));
	szBufSize = PSHK_REG_VALUE_MAX_LEN;


	/* Get the max log file size */
	readRetVal = RegQueryValueEx(hk, "maxlogsize", NULL, NULL, (LPBYTE)szBuf, &szBufSize);
	if( readRetVal == ERROR_SUCCESS )
	{
		m_maxlogsize = _T("");
		m_maxlogsize.Insert(0, szBuf);
	}
	memset(szBuf, 0, sizeof(szBuf));
	szBufSize = PSHK_REG_VALUE_MAX_LEN;

	/* Get the post password change program file */
	readRetVal = RegQueryValueEx(hk, "postChangeProg", NULL, NULL, (LPBYTE)szBuf, &szBufSize);
	if( readRetVal == ERROR_SUCCESS )
	{
		m_postChangeProg.Insert(0, szBuf);
	}
	memset(szBuf, 0, sizeof(szBuf));
	szBufSize = PSHK_REG_VALUE_MAX_LEN;

	/* Get the post password change program args */
	readRetVal = RegQueryValueEx(hk, "postChangeProgArgs", NULL, NULL, (LPBYTE)szBuf, &szBufSize);
	if( readRetVal == ERROR_SUCCESS )
	{
		m_postChangeProgArgs.Insert(0, szBuf);
	}
	memset(szBuf, 0, sizeof(szBuf));
	szBufSize = PSHK_REG_VALUE_MAX_LEN;

	/* Get the pre password change program file */
	readRetVal = RegQueryValueEx(hk, "preChangeProg", NULL, NULL, (LPBYTE)szBuf, &szBufSize);
	if( readRetVal == ERROR_SUCCESS )
	{
		m_preChangeProg = szBuf;
	}
	memset(szBuf, 0, sizeof(szBuf));
	szBufSize = PSHK_REG_VALUE_MAX_LEN;

	/* Get the pre password change program args */
	readRetVal = RegQueryValueEx(hk, "preChangeProgArgs", NULL, NULL, (LPBYTE)szBuf, &szBufSize);
	if( readRetVal == ERROR_SUCCESS )
	{
		m_preChangeProgArgs.Insert(0, szBuf);
	}
	memset(szBuf, 0, sizeof(szBuf));
	szBufSize = PSHK_REG_VALUE_MAX_LEN;

	/* Get the environment */
	readRetVal = RegQueryValueEx(hk, "environment", NULL, NULL, (LPBYTE)szBuf, &szBufSize);
	if( readRetVal == ERROR_SUCCESS )
	{
		m_environment.Insert(0, szBuf);
	}
	memset(szBuf, 0, sizeof(szBuf));
	szBufSize = PSHK_REG_VALUE_MAX_LEN;

	/* Get wether to urlencode the password string */
	readRetVal = RegQueryValueEx(hk, "urlencode", NULL, NULL, (LPBYTE)szBuf, &szBufSize);
	if( readRetVal == ERROR_SUCCESS )
	{
		if(!_stricmp(szBuf, "true") || \
		!_stricmp(szBuf, "yes") || \
		!_stricmp(szBuf, "on")			)
		m_urlencode = TRUE;
	}

	/* Get wether to redirect script output to logfile */
	readRetVal = RegQueryValueEx(hk, "output2log", NULL, NULL, (LPBYTE)szBuf, &szBufSize);
	if( readRetVal == ERROR_SUCCESS )
	{
		if(!_stricmp(szBuf, "true") || \
		!_stricmp(szBuf, "yes") || \
		!_stricmp(szBuf, "on")			)
		m_inheritHandles = TRUE;
	}
    RegCloseKey(hk);

	if( RegOpenKeyEx(HKEY_LOCAL_MACHINE, "SYSTEM\\CurrentControlSet\\Control\\Lsa",
		0, KEY_QUERY_VALUE, &hk2) != ERROR_SUCCESS )
	{
		MessageBox("ERROR: Failed to open registry key \"SYSTEM\\CurrentControlSet\\Control\\Lsa\"",
			"error opening registry key", MB_ICONERROR);
        return FALSE;
	}

	readRetVal
		= RegQueryValueEx( hk2,"Notification Packages", NULL, NULL, (LPBYTE)szBuf2, &szBufSize2);
	if( readRetVal != ERROR_SUCCESS )
	{
			ErrorMsgBox("ERROR: While reading \"Notification Packages\" from registry : ",
				"error writing to registry", readRetVal);
			return FALSE;
	}

	for(DWORD i=0;i<szBufSize2-1;i++)
		if(szBuf2[i]==0)
			szBuf2[i] = ' ';

	for(i=0;i<szBufSize2-1;i++)
				szBuf2[i] = tolower(szBuf2[i]);

	if( strstr(szBuf2, "passwdhk")==NULL )
		m_enabled = FALSE;
	else m_enabled = TRUE;

	RegCloseKey(hk2);
	UpdateData(FALSE);

	return TRUE;  // return TRUE  unless you set the focus to a control
}

void CPasswdhk_configDlg::OnSysCommand(UINT nID, LPARAM lParam)
{
	if ((nID & 0xFFF0) == IDM_ABOUTBOX)
	{
		CAboutDlg dlgAbout;
		dlgAbout.DoModal();
	}
	else
	{
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
    CHAR szBuf[PSHK_REG_VALUE_MAX_LEN+3];
	DWORD szBufSize = PSHK_REG_VALUE_MAX_LEN;
	DWORD retVal;

	UpdateData(TRUE);

	//Write to registry
	if( RegCreateKeyEx(HKEY_LOCAL_MACHINE, PSHK_REG_KEY, 0,
		"", REG_OPTION_NON_VOLATILE, KEY_WRITE, NULL, &hk, &retVal)
			!= ERROR_SUCCESS )
	{
		MessageBox("Failed to open or create "PSHK_REG_KEY,
			"Registry open/create error", MB_ICONERROR);

		goto done;
	}

	if( retVal == REG_CREATED_NEW_KEY )
	{
		MessageBox("Created registry key "PSHK_REG_KEY, "Created registry key");
	}

	/* host */
	memset(&szBuf, 0, sizeof(szBuf));
	strncpy(szBuf, m_host.GetBuffer(0), sizeof(szBuf)-2);

	retVal = RegSetValueEx(hk, "host", 0, REG_SZ,
			  (LPBYTE)szBuf, strlen(szBuf));

	if(retVal != ERROR_SUCCESS)
	{
		ErrorMsgBox("ERROR: while Writing \"host\" to registry :",
				"error writing to registry", retVal);
		goto done;
	}

	/* secret */
	memset(&szBuf, 0, sizeof(szBuf));
	strncpy(szBuf, m_secret.GetBuffer(0), sizeof(szBuf)-2);

	retVal = RegSetValueEx(hk, "secret", 0, REG_SZ,
			  (LPBYTE)szBuf, strlen(szBuf));

	if(retVal != ERROR_SUCCESS)
	{
		ErrorMsgBox("ERROR: while Writing \"secret\" to registry :",
				"error writing to registry", retVal);
		goto done;
	}

	/* port */
	memset(&szBuf, 0, sizeof(szBuf));
	strncpy(szBuf, m_port.GetBuffer(0), sizeof(szBuf)-2);

	retVal = RegSetValueEx(hk, "port", 0, REG_SZ,
			  (LPBYTE)szBuf, strlen(szBuf));

	if(retVal != ERROR_SUCCESS)
	{
		ErrorMsgBox("ERROR: while Writing \"port\" to registry :",
				"error writing to registry", retVal);
		goto done;
	}

	/* logfile */
	memset(&szBuf, 0, sizeof(szBuf));
	strncpy(szBuf, m_logfile.GetBuffer(0), sizeof(szBuf)-2);

	retVal = RegSetValueEx(hk, "logfile", 0, REG_SZ,
			  (LPBYTE)szBuf, strlen(szBuf));

	if(retVal != ERROR_SUCCESS)
	{
		ErrorMsgBox("ERROR: while Writing \"logfile\" to registry :",
				"error writing to registry", retVal);
		goto done;
	}

	/* maxlogsize */
	memset(&szBuf, 0, sizeof(szBuf));
	strncpy(szBuf, m_maxlogsize.GetBuffer(0), sizeof(szBuf)-2);

	retVal = RegSetValueEx(hk, "maxlogsize", 0, REG_SZ,
			  (LPBYTE)szBuf, strlen(szBuf));

	if(retVal != ERROR_SUCCESS)
	{
		ErrorMsgBox("ERROR: while Writing \"maxlogsize\" to registry :",
				"error writing to registry", retVal);
		goto done;
	}

	/* loglevel */
	memset(&szBuf, 0, sizeof(szBuf));
	strncpy(szBuf, m_loglevel.GetBuffer(0), sizeof(szBuf)-2);

	retVal = RegSetValueEx(hk, "loglevel", 0, REG_SZ,
			  (LPBYTE)szBuf, strlen(szBuf));

	if(retVal != ERROR_SUCCESS)
	{
		ErrorMsgBox("ERROR: while Writing \"loglevel\" to registry :",
				"error writing to registry", retVal);
		goto done;
	}

	/* priority */
	memset(&szBuf, 0, sizeof(szBuf));
	strncpy(szBuf, m_priority.GetBuffer(0), sizeof(szBuf)-2);

	retVal = RegSetValueEx(hk, "priority", 0, REG_SZ,
			  (LPBYTE)szBuf, strlen(szBuf));

	if(retVal != ERROR_SUCCESS)
	{
		ErrorMsgBox("ERROR: while Writing \"priority\" to registry :",
				"error writing to registry", retVal);
		goto done;
	}

	/* preChangeProgWait */
	memset( &szBuf, 0, sizeof(szBuf) );
	strncpy( szBuf, m_preChangeProgWait.GetBuffer(0), sizeof(szBuf)-2 );

	retVal = RegSetValueEx(hk, "preChangeProgWait", 0, REG_SZ,
			  (LPBYTE)szBuf, strlen(szBuf));

	if(retVal != ERROR_SUCCESS)
	{
		ErrorMsgBox("ERROR: while Writing \"preChangeWait\" to registry :",
				"error writing to registry", retVal);
		goto done;
	}

	/* postChangeProgWait */
	memset( &szBuf, 0, sizeof(szBuf) );
	strncpy( szBuf, m_postChangeProgWait.GetBuffer(0), sizeof(szBuf)-2 );

	retVal = RegSetValueEx(hk, "postChangeProgWait", 0, REG_SZ,
			  (LPBYTE)szBuf, strlen(szBuf));

	if(retVal != ERROR_SUCCESS)
	{
		ErrorMsgBox("ERROR: while Writing \"postChangeProgWait\" to registry :",
				"error writing to registry", retVal);
		goto done;
	}

	/* workingdir */
	memset(&szBuf, 0, sizeof(szBuf));
	strncpy(szBuf, m_workingdir.GetBuffer(0), sizeof(szBuf)-2);

	retVal = RegSetValueEx(hk, "workingdir", 0, REG_SZ,
			  (LPBYTE)szBuf, strlen(szBuf));

	if(retVal != ERROR_SUCCESS)
	{
		ErrorMsgBox("ERROR: while Writing \"workingdir\" to registry :",
				"error writing to registry", retVal);
		goto done;
	}

	/* postChangeProg */
	memset(&szBuf, 0, sizeof(szBuf));
	strncpy(szBuf, m_postChangeProg.GetBuffer(0), sizeof(szBuf)-2);

	retVal = RegSetValueEx(hk, "postChangeProg", 0, REG_SZ,
			  (LPBYTE)szBuf, strlen(szBuf));

	if(retVal != ERROR_SUCCESS)
	{
		ErrorMsgBox("ERROR: while Writing \"postChangeProg\" to registry :",
				"error writing to registry", retVal);
		goto done;
	}

	/* postChangeProgArgs */
	memset(&szBuf, 0, sizeof(szBuf));
	strncpy(szBuf, m_postChangeProgArgs.GetBuffer(0), sizeof(szBuf)-2);

	retVal = RegSetValueEx(hk, "postChangeProgArgs", 0, REG_SZ,
			  (LPBYTE)szBuf, strlen(szBuf));

	if(retVal != ERROR_SUCCESS)
	{
		ErrorMsgBox("ERROR: while Writing \"postChangeProg args\" to registry :",
				"error writing to registry", retVal);
		goto done;
	}

	/* preChangeProg */
	memset(&szBuf, 0, sizeof(szBuf));
	strncpy(szBuf, m_preChangeProg.GetBuffer(0), sizeof(szBuf)-2);

	retVal = RegSetValueEx(hk, "preChangeProg", 0, REG_SZ,
			  (LPBYTE)szBuf, strlen(szBuf));

	if(retVal != ERROR_SUCCESS)
	{
		ErrorMsgBox("ERROR: while Writing \"preChangeProg\" to registry :",
				"error writing to registry", retVal);
		goto done;
	}

	/* preChangeProg args */
	memset(&szBuf, 0, sizeof(szBuf));
	strncpy(szBuf, m_preChangeProgArgs.GetBuffer(0), sizeof(szBuf)-2);

	retVal = RegSetValueEx(hk, "preChangeProgArgs", 0, REG_SZ,
			  (LPBYTE)szBuf, strlen(szBuf));

	if(retVal != ERROR_SUCCESS)
	{
		ErrorMsgBox("ERROR: while Writing \"preChangeProg args\" to registry :",
				"error writing to registry", retVal);
		goto done;
	}

	/* environment */
	memset(&szBuf, 0, sizeof(szBuf));
	strncpy(szBuf, m_environment.GetBuffer(0), sizeof(szBuf)-2);

	retVal = RegSetValueEx(hk, "environment", 0, REG_SZ,
			  (LPBYTE)szBuf, strlen(szBuf));

	if(retVal != ERROR_SUCCESS)
	{
		ErrorMsgBox("ERROR: while Writing \"environment\" to registry :",
				"error writing to registry", retVal);
		goto done;
	}

	/* urlencode */
	memset(&szBuf, 0, sizeof(szBuf));
	if(m_urlencode==TRUE)
		strcpy(szBuf, "true");
	else strcpy(szBuf, "false");

	retVal = RegSetValueEx(hk, "urlencode", 0, REG_SZ,
			  (LPBYTE)szBuf, strlen(szBuf));

	if(retVal != ERROR_SUCCESS)
	{
		ErrorMsgBox("ERROR: while Writing \"urlencode\" to registry :",
				"error writing to registry", retVal);
		goto done;
	}

	/* output2log */
	memset(&szBuf, 0, sizeof(szBuf));
	if(m_inheritHandles==TRUE)
		strcpy(szBuf, "true");
	else strcpy(szBuf, "false");

	retVal = RegSetValueEx(hk, "output2log", 0, REG_SZ,
			  (LPBYTE)szBuf, strlen(szBuf));

	if(retVal != ERROR_SUCCESS)
	{
		ErrorMsgBox("ERROR: while Writing \"output2log\" to registry :",
				"error writing to registry", retVal);
		goto done;
	}

done:
	RegCloseKey(hk);
	CDialog::OnOK();
}

void CPasswdhk_configDlg::OnEnablecheck()
{
	HKEY hk;
    char szBuf[PSHK_REG_VALUE_MAX_LEN+1];
	char szBuf2[PSHK_REG_VALUE_MAX_LEN+1];
	char *newvalue, *pos;
	DWORD szBufSize = PSHK_REG_VALUE_MAX_LEN;
	DWORD readRetVal;
	DWORD newvalSize;

	UpdateData(TRUE);

	memset(szBuf, 0, sizeof(szBuf));

	if( RegOpenKeyEx(HKEY_LOCAL_MACHINE, "SYSTEM\\CurrentControlSet\\Control\\Lsa",
		0, KEY_ALL_ACCESS, &hk) != ERROR_SUCCESS )
	{
		MessageBox("ERROR: Failed to open registry key \"SYSTEM\\CurrentControlSet\\Control\\Lsa\"",
			"error opening registry key", MB_ICONERROR);
        return;
	}

	readRetVal
		= RegQueryValueEx( hk,"Notification Packages", NULL, NULL, (LPBYTE)szBuf, &szBufSize);
	if( readRetVal != ERROR_SUCCESS )
	{
		MessageBox("ERROR: while reading \"Notification Packages\" from registry",
			"error reading registry key", MB_ICONERROR);
		return;
	}

	for(DWORD i=0;i<szBufSize-1;i++)
		if(szBuf[i]==0)
			szBuf[i] = ' ';

	for(i=1;i<szBufSize-1;i++)
		if(szBuf[i]==' ' && szBuf[i-1]==' ')
			strcpy(&szBuf[i-1], &szBuf[i]);

	szBuf[szBufSize-1] = 0;
	memcpy(&szBuf2, &szBuf, sizeof(szBuf2));
	for(i=0;i<szBufSize-1;i++)
				szBuf[i] = tolower(szBuf[i]);

	newvalue = (char *)calloc(1, strlen(szBuf)+strlen("passwdhk")+8);
	pos=strstr(szBuf, "passwdhk");
	if(pos==NULL)
	{
		if(m_enabled)
		{
			strncpy(newvalue, szBuf2, szBufSize-1);

			pshk_trim(newvalue);

			strcat(newvalue, " passwdhk");

			//Now convert the string to several seperate strings
			newvalSize = strlen(newvalue)+2;
			for( i=0; i<newvalSize; i++ )
				if(newvalue[i] == ' ')
					newvalue[i] = 0;

			int retVal = RegSetValueEx(hk, "Notification Packages", 0, REG_MULTI_SZ,
				  (LPBYTE)newvalue, newvalSize);

			if(retVal != ERROR_SUCCESS)
			{
				ErrorMsgBox("ERROR: while Writing \"Notification Packages\" to registry :",
					"error writing to registry", retVal);
				return;
			}
			MessageBox("eBox password hook enabled in registry.", "success", MB_ICONINFORMATION);
		}
		else
		{
			MessageBox("eBox password hook is already disabled in the registry",
				"Disabling eBox password hook in registry notification packages",
				MB_ICONINFORMATION);
		}
	}
	else
	{
		if(m_enabled)
		{
			MessageBox("eBox password hook is already registered in the registry",
				"Enabling eBox password hook in registry notification packages",
				MB_ICONINFORMATION);
		}
		else
		{
			DWORD i = strlen(szBuf2) - strlen(pos);
			strncpy(newvalue, szBuf2, szBufSize-1);
			strcpy(&newvalue[i], &newvalue[i+8]);
			memset(&newvalue[szBufSize-8], 0, 7);
			if(newvalue[strlen(newvalue)-1]==' ')
				newvalue[strlen(newvalue)-1]=0;

			pshk_trim(newvalue);

			//Now convert the string to several seperate strings
			newvalSize = strlen(newvalue)+2;
			for( i=0; i<newvalSize; i++ )
				if(newvalue[i] == ' ')
					newvalue[i] = 0;

			int retVal = RegSetValueEx(hk, "Notification Packages", 0, REG_MULTI_SZ,
				  (LPBYTE)newvalue, newvalSize);

			if(retVal != ERROR_SUCCESS)
			{
				ErrorMsgBox("ERROR: while Writing \"Notification Packages\" to registry :",
					"error writing to registry", retVal);
				return;
			}

			MessageBox("eBox password hook disabled in registry.", "success", MB_ICONINFORMATION);
		}
	}

	free(newvalue);
	memset(szBuf, 0, sizeof(szBuf));
	szBufSize = PSHK_REG_VALUE_MAX_LEN;

	RegCloseKey(hk);
}

void CPasswdhk_configDlg::ErrorMsgBox(char *errstr, char *title, int err)
{
		char *lpBuf;

		FormatMessage(
			FORMAT_MESSAGE_ALLOCATE_BUFFER |
			FORMAT_MESSAGE_FROM_SYSTEM |
			FORMAT_MESSAGE_IGNORE_INSERTS,
			NULL,
			err,
			MAKELANGID(LANG_NEUTRAL, SUBLANG_DEFAULT), // Default language
			(LPTSTR) &lpBuf,
			0,
			NULL );

		char *tmp = (char *)calloc(1, strlen(lpBuf)+strlen(errstr)+4);
		strcpy(tmp, errstr);
		strcat(tmp, lpBuf);

		MessageBox(tmp, title, MB_ICONERROR);
		LocalFree(lpBuf);
}
