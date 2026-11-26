import { describe, it, expect, afterEach } from "@jest/globals";
import fs from "node:fs";
import os from "node:os";
import path from "node:path";
import {
  acquireInstanceLock,
  readProcessCommandLine,
  type CommandLineProbes,
  type InstanceLock,
} from "../src/instance-lock.js";

describe("instance lock", () => {
  let tmpDir: string | null = null;
  const locks: InstanceLock[] = [];

  afterEach(() => {
    while (locks.length > 0) {
      locks.pop()?.release();
    }
    if (tmpDir) {
      fs.rmSync(tmpDir, { recursive: true, force: true });
      tmpDir = null;
    }
  });

  function baseDir(): string {
    tmpDir ??= fs.mkdtempSync(path.join(os.tmpdir(), "lightroom-mcp-lock-test-"));
    return tmpDir;
  }

  const asBridge = () => "node D:\\work\\lightroom-mcp\\server\\dist\\index.js";

  it("rejects a second live bridge for the same ports", () => {
    locks.push(acquireInstanceLock(58763, 58764, baseDir(), asBridge));

    expect(() => acquireInstanceLock(58763, 58764, baseDir(), asBridge)).toThrow(
      /Another Lightroom MCP bridge is already running/,
    );
  });

  it("replaces a lock whose recycled PID now belongs to an unrelated process", () => {
    const dir = baseDir();
    const lockFile = path.join(dir, "bridge-58763-58764.lock");
    // process.pid is alive, but we report it as an unrelated program.
    fs.writeFileSync(lockFile, `${process.pid}\n`);

    locks.push(acquireInstanceLock(58763, 58764, dir, () => "ChatGPT.exe --type=renderer"));

    expect(fs.readFileSync(lockFile, "utf8")).toBe(`${process.pid}\n`);
  });

  it("keeps the lock when the holder's command line cannot be determined", () => {
    const dir = baseDir();
    fs.writeFileSync(path.join(dir, "bridge-58763-58764.lock"), `${process.pid}\n`);

    expect(() => acquireInstanceLock(58763, 58764, dir, () => null)).toThrow(
      /Another Lightroom MCP bridge is already running/,
    );
  });

  it("reads the command line of the current process", () => {
    const cmd = readProcessCommandLine(process.pid);

    expect(typeof cmd).toBe("string");
    expect(cmd).not.toBe("");
  }, 30000);

  describe("readProcessCommandLine platform probes", () => {
    const probes = (
      platform: NodeJS.Platform,
      overrides: Partial<CommandLineProbes> = {},
    ): CommandLineProbes => ({
      platform,
      run: () => "",
      readFile: () => "",
      ...overrides,
    });

    it("queries PowerShell on win32", () => {
      const calls: string[][] = [];
      const cmd = readProcessCommandLine(
        42,
        probes("win32", {
          run: (file, args) => {
            calls.push([file, ...args]);
            return "node lightroom-mcp\\index.js\r\n";
          },
        }),
      );

      expect(cmd).toBe("node lightroom-mcp\\index.js");
      expect(calls[0]?.[0]).toBe("powershell.exe");
      expect(calls[0]?.join(" ")).toContain("ProcessId=42");
    });

    it("reads /proc cmdline on linux and turns NULs into spaces", () => {
      const files: string[] = [];
      const cmd = readProcessCommandLine(
        7,
        probes("linux", {
          readFile: (file) => {
            files.push(file);
            return "node\0server.js\0";
          },
        }),
      );

      expect(cmd).toBe("node server.js");
      expect(files).toEqual(["/proc/7/cmdline"]);
    });

    it("uses ps on other platforms", () => {
      const cmd = readProcessCommandLine(
        9,
        probes("darwin", { run: (file, args) => `${file} ${args.join(" ")}\n` }),
      );

      expect(cmd).toBe("ps -p 9 -o command=");
    });

    it("returns null when the probe output is empty or the probe throws", () => {
      expect(readProcessCommandLine(5, probes("win32", { run: () => "  \n" }))).toBeNull();
      expect(
        readProcessCommandLine(
          5,
          probes("linux", {
            readFile: () => {
              throw new Error("ENOENT");
            },
          }),
        ),
      ).toBeNull();
    });
  });

  it("returns null for an invalid PID", () => {
    expect(readProcessCommandLine(0)).toBeNull();
    expect(readProcessCommandLine(-5)).toBeNull();
  });

  it("allows different port pairs to run independently", () => {
    locks.push(acquireInstanceLock(58763, 58764, baseDir()));
    locks.push(acquireInstanceLock(58765, 58766, baseDir()));
  });

  it("replaces a stale lock with a fully written live lock", () => {
    const dir = baseDir();
    const lockFile = path.join(dir, "bridge-58763-58764.lock");
    fs.writeFileSync(lockFile, "999999999\n");

    locks.push(acquireInstanceLock(58763, 58764, dir));

    expect(fs.readFileSync(lockFile, "utf8")).toBe(`${process.pid}\n`);
  });

  it("replaces a malformed stale lock", () => {
    const dir = baseDir();
    const lockFile = path.join(dir, "bridge-58763-58764.lock");
    fs.writeFileSync(lockFile, "not-a-pid\n");

    locks.push(acquireInstanceLock(58763, 58764, dir));

    expect(fs.readFileSync(lockFile, "utf8")).toBe(`${process.pid}\n`);
  });

  it("allows release after the lock file is already gone", () => {
    const dir = baseDir();
    const lockFile = path.join(dir, "bridge-58763-58764.lock");
    const lock = acquireInstanceLock(58763, 58764, dir);
    fs.unlinkSync(lockFile);

    lock.release();
    lock.release();

    expect(fs.existsSync(lockFile)).toBe(false);
  });

  it("removes process handlers when released", () => {
    const beforeExit = process.listenerCount("exit");
    const beforeSigint = process.listenerCount("SIGINT");
    const beforeSigterm = process.listenerCount("SIGTERM");

    const lock = acquireInstanceLock(58763, 58764, baseDir());
    expect(process.listenerCount("exit")).toBe(beforeExit + 1);
    expect(process.listenerCount("SIGINT")).toBe(beforeSigint + 1);
    expect(process.listenerCount("SIGTERM")).toBe(beforeSigterm + 1);

    lock.release();

    expect(process.listenerCount("exit")).toBe(beforeExit);
    expect(process.listenerCount("SIGINT")).toBe(beforeSigint);
    expect(process.listenerCount("SIGTERM")).toBe(beforeSigterm);
  });
});
