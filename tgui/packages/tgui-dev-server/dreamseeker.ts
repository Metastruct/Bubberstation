/**
 * @file
 * @copyright 2020 Aleksej Komarov
 * @license MIT
 */

import { exec } from 'node:child_process';
import { promisify } from 'node:util';

import axios, { type AxiosInstance, type AxiosResponse } from 'axios';

import { createLogger } from './logging';

type Entry = {
  addr: string;
  pid: number;
};

const logger = createLogger('dreamseeker');

const instanceByPid = new Map();

export class DreamSeeker {
  public pid: number;
  public addr: string;
  public client: AxiosInstance;

  constructor(pid: number, addr: string) {
    this.pid = pid;
    this.addr = addr;
    this.client = axios.create({
      baseURL: `http://${addr}`,
    });
  }

  topic(params: Record<string, any> = {}): Promise<AxiosResponse> {
    const query = Object.keys(params)
      .map(
        (key) =>
          `${encodeURIComponent(key)}=${encodeURIComponent(params[key])}`,
      )
      .join('&');
    logger.log(
      `topic call at ${this.client.defaults.baseURL}/dummy.htm?${query}`,
    );
    return this.client.get(`/dummy.htm?${query}`);
  }

  static async getInstancesByPids(pids: number[]): Promise<DreamSeeker[]> {
    const instances: DreamSeeker[] = [];
    const pidsToResolve: number[] = [];

    for (const pid of pids) {
      const instance = instanceByPid.get(pid);
      if (instance) {
        instances.push(instance);
      } else {
        pidsToResolve.push(pid);
      }
    }

    if (pidsToResolve.length === 0) {
      return instances;
    }

    const command = getListCommand();

    try {
      const { stdout } = await promisify(exec)(command, {
        // Max buffer of 1MB (default is 200KB)
        maxBuffer: 1024 * 1024,
      });

      const entries = parseEntries(stdout).filter((entry) =>
        pidsToResolve.includes(entry.pid),
      );

      const len = entries.length;
      logger.log('found', len, plural('instance', len));
      for (const entry of entries) {
        const { pid, addr } = entry;
        const instance = new DreamSeeker(pid, addr);
        instances.push(instance);
        instanceByPid.set(pid, instance);
      }
    } catch (err) {
      if (err.code === 'ERR_CHILD_PROCESS_STDIO_MAXBUFFER') {
        logger.error(err.message, err.code);
      } else {
        logger.error(err);
      }
      return [];
    }
    return instances;
  }
}

function plural(word: string, n: number): string {
  return n !== 1 ? `${word}s` : word;
}

function getListCommand(): string {
  if (process.platform === 'win32') {
    return 'netstat -ano | findstr TCP | findstr 0.0.0.0:0';
  }
  // ss is part of iproute2, present on virtually every modern Linux distro.
  return 'ss -tlnp';
}

function parseEntries(stdout: string): Entry[] {
  const entries: Entry[] = [];

  if (process.platform === 'win32') {
    // Line format: proto addr mask mode pid
    for (const line of stdout.split('\r\n')) {
      const words = line.match(/\S+/g);
      if (!words || words.length === 0) {
        continue;
      }
      entries.push({ addr: words[1], pid: parseInt(words[4], 10) });
    }
    return entries;
  }

  // ss -tlnp output:
  // State  Recv-Q Send-Q Local Address:Port  Peer Address:Port Process
  // LISTEN 0      4096   0.0.0.0:1338        0.0.0.0:*         users:(("DreamDaemon",pid=1234,fd=3))
  for (const line of stdout.split('\n').slice(1)) {
    const words = line.match(/\S+/g);
    if (!words || words.length < 4) {
      continue;
    }
    const pidMatch = line.match(/pid=(\d+)/);
    if (!pidMatch) {
      continue;
    }
    entries.push({ addr: words[3], pid: parseInt(pidMatch[1], 10) });
  }
  return entries;
}
