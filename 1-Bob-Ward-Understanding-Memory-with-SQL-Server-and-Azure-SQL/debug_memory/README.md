# Demo for using the debugger to look at memory

## WARNING: DO NOT TRY THIS ON A PRODUCTION SERVER. PLEASE USE A VM, your laptop, or a test machine you have exclusive access to

- Deploy SQL Server 2019 on Windows
- Install the Windows Debugger and make sure the install folder is in your path
- Stop the SQL Server service
- Start SQL Server from the command line like this:

`windbg -y srv*https://msdl.microsoft.com/download/symbols sqlservr.exe -c`

- The debugger will come up and be at a debugger command prompt
- Set a breakpoint with this command in the debugger window:

bp kernelbase!AllocateUserPhysicalPagesNuma

- Type 'g' to run SQL Server
- A breakpoint will hit. Type in 'k' to view callstacks
- Keep using 'g' and 'k' to see various call stacks on how SQL Server allocates memory at startup.