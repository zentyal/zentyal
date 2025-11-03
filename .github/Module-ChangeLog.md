# 📝 Module ChangeLog Guide

Hey contributor! 👋
Before opening a Pull Request (PR), make sure you’ve updated the module’s ChangeLog file — otherwise, the PR won’t be approved.

Each module keeps a ChangeLog that lists its version history and a short note about what changed.
So whenever you fix a bug, add a feature, or make any relevant update, bump the module version and describe what you did.

## Example

Let’s say you fixed a bug in the DNS module — specifically in the stub file named.conf.options.mas.
You’d then update main/dns/ChangeLog like this:

```sh
8.0.2
	+ Fix bug reported in issue #2219
8.0.1
	+ Hide Bind9 version
8.0.0
	+ Set version to 8.0.0
	+ Update Bind9 configuration
	+ Add a new stub
	+ Remove old Systemd fix
	+ Update initial-setup and enable-module scripts
	+ Update DLZ file
	+ Update bind9.mas stub
	+ Remove unnecessary network restart
	+ Manage resolv.conf file
```

That’s it! 🎉
You’ve added a new version (8.0.2) and a short description of your change.

## 🚨 Why this matters

We use the ChangeLog to keep track of module updates and build and release the changes automatically.

✅ Quick checklist before submitting your PR:

- [ ] Did you bump the module version?
- [ ] Did you add a short line describing what changed?
- [ ] Did you make sure the ChangeLog file is committed?

If all of these are ✅ — you’re good to go!
