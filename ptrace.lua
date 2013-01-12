local ffi = require("ffi")

ffi.cdef [[

#define	__WEXITSTATUS(status)	(((status) & 0xff00) >> 8)
#define	__WTERMSIG(status)	((status) & 0x7f)
#define	__WSTOPSIG(status)	__WEXITSTATUS(status)
#define	__WIFEXITED(status)	(__WTERMSIG(status) == 0)
#define __WIFSIGNALED(status) \
  (((signed char) (((status) & 0x7f) + 1) >> 1) > 0)
#define	__WIFSTOPPED(status)	(((status) & 0xff) == 0x7f)
#ifdef WCONTINUED
# define __WIFCONTINUED(status)	((status) == __W_CONTINUED)
#endif
#define	__WCOREDUMP(status)	((status) & __WCOREFLAG)
#define	__W_EXITCODE(ret, sig)	((ret) << 8 | (sig))
#define	__W_STOPCODE(sig)	((sig) << 8 | 0x7f)
#define __W_CONTINUED		0xffff
#define	__WCOREFLAG		0x80

enum __ptrace_request
{
  PTRACE_TRACEME = 0,
  PTRACE_PEEKTEXT = 1,
  PTRACE_PEEKDATA = 2,
  PTRACE_PEEKUSER = 3,
  PTRACE_POKETEXT = 4,
  PTRACE_POKEDATA = 5,
  PTRACE_POKEUSER = 6,
  PTRACE_CONT = 7,
  PTRACE_KILL = 8,
  PTRACE_SINGLESTEP = 9,
  PTRACE_GETREGS = 12,
  PTRACE_SETREGS = 13,
  PTRACE_GETFPREGS = 14,
  PTRACE_SETFPREGS = 15,
  PTRACE_ATTACH = 16,
  PTRACE_DETACH = 17,
  PTRACE_GETFPXREGS = 18,
  PTRACE_SETFPXREGS = 19,
  PTRACE_SYSCALL = 24,
  PTRACE_SETOPTIONS = 0x4200,
  PTRACE_GETEVENTMSG = 0x4201,
  PTRACE_GETSIGINFO = 0x4202,
  PTRACE_SETSIGINFO = 0x4203,
  PTRACE_GETREGSET = 0x4204,
  PTRACE_SETREGSET = 0x4205,
  PTRACE_SEIZE = 0x4206,
  PTRACE_INTERRUPT = 0x4207,
  PTRACE_LISTEN = 0x4208
};

typedef int pid_t;

long  ptrace  (enum __ptrace_request request,
	           pid_t                 pid,
	           void                * addr,
	           void                * data);
pid_t fork    ();
int execv     (const char * path, const char * argv[]);
pid_t waitpid (pid_t pid, int * stat_loc, int options);
]]



Ptrace = {}
Ptrace.__index = Ptrace

function Ptrace.debug (program_filename)
	if ffi.arch ~= "x64" then
		error("unsupported architecture")
	end

	local pid = ffi.C.fork()

	if pid == -1 then
		error("could not fork")
	elseif pid == 0 then
		local ttype = ffi.typeof("const char *[?]")
		local args = ttype(#program_filename + 1, {program_filename})
		args[0] = program_filename
		ffi.C.ptrace(ffi.C.PTRACE_TRACEME, 0, nil, nil)
		ffi.C.execv(program_filename, args)
	else
		local ptrace = {}
		setmetatable(ptrace, Ptrace)
		ptrace.pid = pid
		ptrace.breakpoints = {}
		return ptrace
	end
end


function Ptrace.WAIT_SIGTRAP (ptrace)
	local status = ffi.cdata("int[1]")

	while true do
		waitpid(ptrace.pid, status, 0)
		if 
end


function Ptrace.add_breakpoint (ptrace, address)
	table.insert(ptrace.breakpoints, address)
end


function Ptrace.continue (ptrace)
	local tmp

	if ffi.arch == "x64" then
		tmp = ffi.cdata("uint64_t")
	end

	for k,breakpoint in pairs(ptrace.breakpoints) do
		tmp = ptrace()
	end
end

print(ptrace.debug('/usr/ls'))