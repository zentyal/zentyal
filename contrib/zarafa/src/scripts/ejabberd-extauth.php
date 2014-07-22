#!/usr/bin/php
<?php

/*
Based on work by
Copyright (c) <2005> LISSY Alexandre, "lissyx" <alexandrelissy@free.fr>
*/

error_reporting(0);
$auth = new JabberAuth();
$auth->zarafa_urls = array("http://localhost/webapp");

$auth->play(); // We simply start process !

class JabberAuth {
	var $zarafapath; 

	var $debug 		= false; 				      /* Debug mode */
	var $debugfile 	= "/var/log/pipe-debug.log";  /* Debug output */
	var $logging 	= false; 				      /* Do we log requests ? (syslog) */
	/*
	 * For both debug and logging, ejabberd have to be able to write.
	 */
	
	var $jabber_user;   /* This is the jabber user passed to the script. filled by $this->command() */
	var $jabber_pass;   /* This is the jabber user password passed to the script. filled by $this->command() */
	var $jabber_server; /* This is the jabber server passed to the script. filled by $this->command(). Useful for VirtualHosts */
	var $data;          /* This is what SM component send to us. */
	
	var $command; /* This is the command sent ... */
	var $stdin;   /* stdin file pointer */
	var $stdout;  /* stdout file pointer */

	function JabberAuth()
	{
		@define_syslog_variables();
		@openlog("pipe-auth", LOG_NDELAY, LOG_SYSLOG);
		
		if($this->debug) {
			@error_reporting(E_ALL);
			@ini_set("log_errors", "1");
			@ini_set("error_log", $this->debugfile);
		}
		$this->logg("Starting pipe-auth ..."); // We notice that it's starting ...
		$this->openstd();
	}
	
	function stop()
	{
		$this->logg("Shutting down ..."); // Sorry, have to go ...
		closelog();
		$this->closestd(); // Simply close files
		exit(0); // and exit cleanly
	}
	
	function openstd()
	{
		$this->stdout = @fopen("php://stdout", "w"); // We open STDOUT so we can read
		$this->stdin  = @fopen("php://stdin", "r"); // and STDIN so we can talk !
	}
	
	function readstdin()
	{
		$l      = @fgets($this->stdin, 3); // We take the length of string
		$length = @unpack("n", $l); // ejabberd give us something to play with ...
		$len    = $length["1"]; // and we now know how long to read.
		if($len > 0) { // if not, we'll fill logfile ... and disk full is just funny once
			$this->logg("Reading $len bytes ... "); // We notice ...
			$data   = @fgets($this->stdin, $len+1);
			// $data = iconv("UTF-8", "ISO-8859-15", $data); // To be tested, not sure if still needed.
			$this->data = $data; // We set what we got.
			$this->logg("IN: ".$data);
		}
	}
	
	function closestd()
	{
		@fclose($this->stdin); // We close everything ...
		@fclose($this->stdout);
	}
	
	function out($message)
	{
		@fwrite($this->stdout, $message); // We reply ...
		@fflush($this->stdout);
		$dump = @unpack("nn", $message);
		$dump = $dump["n"];
		$this->logg("OUT: ". $dump);
	}
	
	function play()
	{
		do {
			$this->readstdin(); // get data
			$length = strlen($this->data); // compute data length
			if($length > 0 ) { // for debug mainly ...
				$this->logg("GO: ".$this->data);
				$this->logg("data length is : ".$length);
			}
			$ret = $this->command(); // play with data !
			$this->logg("RE: " . $ret); // this is what WE send.
			$this->out($ret); // send what we reply.
			$this->data = NULL; // more clean. ...
		} while (true);
	}
	
	function command()
	{
		$data = $this->splitcomm(); // This is an array, where each node is part of what SM sent to us :
		// 0 => the command,
		// and the others are arguments .. e.g. : user, server, password ...
		
		if(strlen($data[0]) > 0 ) {
			$this->logg("Command was : ".$data[0]);
		}
		switch($data[0]) {
			case "isuser": // this is the "isuser" command, used to check for user existance
					$this->jabber_user = $data[1];
					$parms = $data[1];  // only for logging purpose
					$return = $this->checkuser();
				break;
				
			case "auth": // check login, password
					$this->jabber_user = $data[1];
					$this->jabber_pass = $data[3];
					$parms = $data[1].":".$data[2].":".md5($data[3]); // only for logging purpose
					$return = $this->checkpass();
				break;
				
			case "setpass":
					$return = false; // We do not want jabber to be able to change password
				break;
				
			default:
					$this->stop(); // if it's not something known, we have to leave.
					// never had a problem with this using ejabberd, but might lead to problem ?
				break;
		}
		
		$return = ($return) ? 1 : 0;
		
		if(strlen($data[0]) > 0 && strlen($parms) > 0) {
			$this->logg("Command : ".$data[0].":".$parms." ==> ".$return." ");
		}
		return @pack("nn", 2, $return);
	}
	
	function checkpass()
	{
		foreach($this->zarafa_urls as $url) {
		    if($this->checkpassWA($url))
		        return true;
		}
	        
        return false;
    }
            
    function checkpassWA($url)
    {
		$this->logg("checkpass " . $this->jabber_pass);
		$pass = $this->jabber_pass;
		$user = $this->jabber_user;
		
		// Only accept alnum cookies
		if(!preg_match("/[a-zA-Z0-9]+/", $pass)) {
		    $this->logg("bad pass");
			return false;
        }

		$ctx = stream_context_create(array("http" => 
										array("method" => "GET",
											  "header" => "Cookie: ZARAFA_WEBAPP=$pass\r\n" ) ) );

		$fp = fopen($url . "/index.php?verify=$user", "rt", false, $ctx);
		$ok = fgets($fp);
		
		$this->logg("got $ok");
		
		if($ok === "1")
			return true;
		else
		{
	                $fp = fopen($this->zarafa_url_de . "/index.php?verify=$user", "rt", false, $ctx);
	                $ok = fgets($fp);

	                $this->logg("got $ok");

	                if($ok === "1")
		          return true;
		}
			
        return false;
	}
	
	function checkuser()
	{
		// I guess you should send 'false' if the user auth'd and then was deleted
		return true;
	}
	
	function splitcomm() // simply split command and arugments into an array.
	{
		return explode(":", $this->data);
	}
	
	function logg($message) // pretty simple, using syslog.
	{
		if($this->logging) {
			@syslog(LOG_INFO, $message);
		}
	}
}

?>
