import { execFileSync } from "node:child_process";
import fs from "node:fs";
import os from "node:os";
import path from "node:path";

export interface InstanceLock {
  release: () => void;
}

function pidIsAlive(pid: number): boolean {
  try {
    process.kill(pid, 0);
    return true;
  } catch (err) {
    return (err as NodeJS.ErrnoException).code === "EPERM";
  }
}

export interface CommandLineProbes {
  platform: NodeJS.Platform;
  run: (file: string, args: string[], timeoutMs: number) => string;
  readFile: (file: string) => string;
}

const defaultProbes: CommandLineProbes = {
  platform: process.platform,
  run: (file, args, timeoutMs) =>
    execFileSync(file, args, {
      encoding: "utf8",
      timeout: timeoutMs,
      windowsHide: true,
      stdio: ["ignore", "pipe", "ignore"],
    }),
  readFile: (file) => fs.readFileSync(file, "utf8"),
};

/**
 * Best-effort command line of a running process, or null when it cannot be
 * determined (no permission, tool missing, process gone). Only reached on the
 * lock-contention path, so the slower Windows lookup is acceptable. The probes
 * are injectable so every platform branch can be tested on any OS.
 */
export function readProcessCommandLine(
  pid: number,
  probes: CommandLineProbes = defaultProbes,
): string | null {
  if (!Number.isInteger(pid) || pid <= 0) return null;
  try {
    let out: string;
    if (probes.platform === "win32") {
      out = probes.run(
        "powershell.exe",
        [
          "-NoProfile",
          "-NonInteractive",
          "-Command",
          `(Get-CimInstance Win32_Process -Filter "ProcessId=${pid}").CommandLine`,
        ],
        20000,
      );
    } else if (probes.platform === "linux") {
      out = probes.readFile(`/proc/${pid}/cmdline`).replaceAll("\0", " ");
    } else {
      out = probes.run("ps", ["-p", String(pid), "-o", "command="], 5000);
    }
    const trimmed = out.trim();
    return trimmed === "" ? null : trimmed;
  } catch {
    return null;
  }
}

const BRIDGE_COMMAND_LINE = /lightroom[-_ ]?mcp/i;

/**
 * A live PID only counts as a running bridge when its command line looks like
 * one. Operating systems recycle PIDs, so a stale lock can point at an
 * unrelated process. When the command line is unknown, assume it is a bridge
 * (the conservative, pre-existing behaviour).
 */
function holderIsBridge(pid: number, commandLineOf: (pid: number) => string | null): boolean {
  const cmd = commandLineOf(pid);
  if (cmd === null) return true;
  if (BRIDGE_COMMAND_LINE.test(cmd)) return true;
  const entry = process.argv[1];
  return entry !== undefined && entry !== "" && cmd.includes(entry);
}

function readPid(pidFile: string): number | null {
  try {
    const raw = fs.readFileSync(pidFile, "utf8").trim();
    const parsed = Number(raw);
    return Number.isInteger(parsed) && parsed > 0 ? parsed : null;
  } catch {
    return null;
  }
}

export function acquireInstanceLock(
  requestPort: number,
  responsePort: number,
  baseDir = path.join(os.homedir(), ".config", "lightroom-mcp"),
  commandLineOf: (pid: number) => string | null = readProcessCommandLine,
): InstanceLock {
  fs.mkdirSync(baseDir, { recursive: true, mode: 0o700 });
  const lockFile = path.join(baseDir, `bridge-${requestPort}-${responsePort}.lock`);

  while (true) {
    let fd: number | null = null;
    try {
      fd = fs.openSync(lockFile, "wx", 0o600);
      fs.writeFileSync(fd, `${process.pid}\n`, { encoding: "utf8" });
      break;
    } catch (err) {
      const code = (err as NodeJS.ErrnoException).code;
      if (code !== "EEXIST") {
        throw err;
      }

      const existingPid = readPid(lockFile);
      if (existingPid && pidIsAlive(existingPid) && holderIsBridge(existingPid, commandLineOf)) {
        throw new Error(
          `Another Lightroom MCP bridge is already running for ports ${requestPort}/${responsePort} (pid ${existingPid})`,
        );
      }

      try {
        fs.unlinkSync(lockFile);
      } catch (unlinkErr) {
        if ((unlinkErr as NodeJS.ErrnoException).code !== "ENOENT") throw unlinkErr;
      }
    } finally {
      if (fd !== null) fs.closeSync(fd);
    }
  }

  let released = false;
  const exitHandler = () => release();
  const signalHandler = () => {
    release();
    process.exit(0);
  };
  const release = () => {
    if (released) return;
    released = true;
    process.off("exit", exitHandler);
    process.off("SIGINT", signalHandler);
    process.off("SIGTERM", signalHandler);
    if (readPid(lockFile) === process.pid) {
      fs.unlinkSync(lockFile);
    }
  };

  process.once("exit", exitHandler);
  process.once("SIGINT", signalHandler);
  process.once("SIGTERM", signalHandler);

  return { release };
}
