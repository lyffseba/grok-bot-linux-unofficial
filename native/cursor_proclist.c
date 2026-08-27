/*
 * Linux implementation of Cursor's cursor_proclist native API.
 *
 * The Windows/macOS addon is private. The JavaScript wrapper
 * (dist/deps/cursor-proclist/index.js) documents the contract:
 *
 *   cursor_proclist_scan_async(roots?: number[])
 *     -> Promise<Array<[pid, ppid, name, extensionId, cpuTimeMs,
 *                       memoryMB, argv, ownerAgentId, requestId]>>
 *
 *   cursor_proclist_system_memory()
 *     -> { totalBytes, availableBytes, pressureLevel? } | null
 *
 * This file reads /proc so the Linux port actually lists processes
 * instead of shipping an empty stub.
 */

#include <ctype.h>
#include <dirent.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>

#include <node_api.h>

#define MAX_PROCS 8192
#define MAX_ROOTS 64

typedef struct {
  int pid;
  int ppid;
  char name[256];
  unsigned long long utime;
  unsigned long long stime;
  unsigned long rss_pages;
  char argv[1024];
} proc_row;

static int read_file(const char *path, char *buf, size_t buflen) {
  FILE *f = fopen(path, "r");
  if (!f) {
    return -1;
  }
  size_t n = fread(buf, 1, buflen - 1, f);
  fclose(f);
  buf[n] = '\0';
  return (int)n;
}

static int parse_stat(int pid, proc_row *row) {
  char path[64];
  char buf[4096];
  snprintf(path, sizeof(path), "/proc/%d/stat", pid);
  if (read_file(path, buf, sizeof(buf)) < 0) {
    return -1;
  }

  char *rparen = strrchr(buf, ')');
  if (!rparen) {
    return -1;
  }
  char *lparen = strchr(buf, '(');
  if (!lparen || lparen >= rparen) {
    return -1;
  }

  size_t namelen = (size_t)(rparen - lparen - 1);
  if (namelen >= sizeof(row->name)) {
    namelen = sizeof(row->name) - 1;
  }
  memcpy(row->name, lparen + 1, namelen);
  row->name[namelen] = '\0';

  /* After ")": state ppid ... utime stime ... rss (field 24) */
  int ppid = 0;
  unsigned long long utime = 0;
  unsigned long long stime = 0;
  unsigned long rss = 0;
  if (sscanf(rparen + 2,
             "%*c %d %*d %*d %*d %*d %*u %*u %*u %*u %*u %llu %llu %*d %*d "
             "%*d %*d %*d %*d %*u %*u %lu",
             &ppid, &utime, &stime, &rss) < 4) {
    return -1;
  }

  row->pid = pid;
  row->ppid = ppid;
  row->utime = utime;
  row->stime = stime;
  row->rss_pages = rss;
  return 0;
}

static void read_cmdline(int pid, char *out, size_t outlen) {
  char path[64];
  char buf[1024];
  snprintf(path, sizeof(path), "/proc/%d/cmdline", pid);
  int n = read_file(path, buf, sizeof(buf));
  if (n <= 0) {
    out[0] = '\0';
    return;
  }
  for (int i = 0; i < n; i++) {
    if (buf[i] == '\0') {
      buf[i] = ' ';
    }
  }
  while (n > 0 && buf[n - 1] == ' ') {
    n--;
    buf[n] = '\0';
  }
  strncpy(out, buf, outlen - 1);
  out[outlen - 1] = '\0';
}

static int is_descendant(int pid, const int *roots, int nroots,
                         const proc_row *rows, int nrows) {
  if (nroots <= 0) {
    return 1;
  }
  for (int depth = 0; depth < 64 && pid > 0; depth++) {
    for (int i = 0; i < nroots; i++) {
      if (pid == roots[i]) {
        return 1;
      }
    }
    int ppid = 0;
    int found = 0;
    for (int i = 0; i < nrows; i++) {
      if (rows[i].pid == pid) {
        ppid = rows[i].ppid;
        found = 1;
        break;
      }
    }
    if (!found) {
      break;
    }
    pid = ppid;
  }
  return 0;
}

static int collect_procs(proc_row *rows, int max_rows) {
  DIR *dir = opendir("/proc");
  if (!dir) {
    return 0;
  }
  int count = 0;
  struct dirent *ent;
  while ((ent = readdir(dir)) != NULL && count < max_rows) {
    if (!isdigit((unsigned char)ent->d_name[0])) {
      continue;
    }
    int pid = atoi(ent->d_name);
    if (pid <= 0) {
      continue;
    }
    if (parse_stat(pid, &rows[count]) == 0) {
      read_cmdline(pid, rows[count].argv, sizeof(rows[count].argv));
      count++;
    }
  }
  closedir(dir);
  return count;
}

static napi_value ScanAsync(napi_env env, napi_callback_info info) {
  size_t argc = 1;
  napi_value argv[1];
  napi_get_cb_info(env, info, &argc, argv, NULL, NULL);

  int roots[MAX_ROOTS];
  int nroots = 0;
  if (argc >= 1) {
    bool is_array = false;
    napi_is_array(env, argv[0], &is_array);
    if (is_array) {
      uint32_t len = 0;
      napi_get_array_length(env, argv[0], &len);
      if (len > MAX_ROOTS) {
        len = MAX_ROOTS;
      }
      for (uint32_t i = 0; i < len; i++) {
        napi_value item;
        int32_t pid = 0;
        napi_get_element(env, argv[0], i, &item);
        if (napi_get_value_int32(env, item, &pid) == napi_ok && pid > 0) {
          roots[nroots++] = pid;
        }
      }
    }
  }

  proc_row *rows = calloc(MAX_PROCS, sizeof(proc_row));
  if (!rows) {
    napi_throw_error(env, NULL, "out of memory");
    return NULL;
  }
  int nrows = collect_procs(rows, MAX_PROCS);

  long hz = sysconf(_SC_CLK_TCK);
  if (hz <= 0) {
    hz = 100;
  }
  long page = sysconf(_SC_PAGESIZE);
  if (page <= 0) {
    page = 4096;
  }

  napi_value result;
  napi_create_array(env, &result);
  uint32_t out_i = 0;
  for (int i = 0; i < nrows; i++) {
    if (!is_descendant(rows[i].pid, roots, nroots, rows, nrows)) {
      continue;
    }
    napi_value tuple;
    napi_create_array_with_length(env, 9, &tuple);

    napi_value v_pid, v_ppid, v_name, v_ext, v_cpu, v_mem, v_argv, v_owner,
        v_req;
    napi_create_int32(env, rows[i].pid, &v_pid);
    napi_create_int32(env, rows[i].ppid, &v_ppid);
    napi_create_string_utf8(env, rows[i].name, NAPI_AUTO_LENGTH, &v_name);
    napi_create_string_utf8(env, "", NAPI_AUTO_LENGTH, &v_ext);
    double cpu_ms =
        (double)(rows[i].utime + rows[i].stime) * 1000.0 / (double)hz;
    napi_create_double(env, cpu_ms, &v_cpu);
    double mem_mb =
        (double)rows[i].rss_pages * (double)page / (1024.0 * 1024.0);
    napi_create_double(env, mem_mb, &v_mem);
    napi_create_string_utf8(env, rows[i].argv, NAPI_AUTO_LENGTH, &v_argv);
    napi_get_null(env, &v_owner);
    napi_get_null(env, &v_req);

    napi_set_element(env, tuple, 0, v_pid);
    napi_set_element(env, tuple, 1, v_ppid);
    napi_set_element(env, tuple, 2, v_name);
    napi_set_element(env, tuple, 3, v_ext);
    napi_set_element(env, tuple, 4, v_cpu);
    napi_set_element(env, tuple, 5, v_mem);
    napi_set_element(env, tuple, 6, v_argv);
    napi_set_element(env, tuple, 7, v_owner);
    napi_set_element(env, tuple, 8, v_req);
    napi_set_element(env, result, out_i++, tuple);
  }
  free(rows);

  napi_deferred deferred;
  napi_value promise;
  if (napi_create_promise(env, &deferred, &promise) != napi_ok) {
    return NULL;
  }
  napi_resolve_deferred(env, deferred, result);
  return promise;
}

static napi_value SystemMemory(napi_env env, napi_callback_info info) {
  (void)info;
  FILE *f = fopen("/proc/meminfo", "r");
  if (!f) {
    napi_value n;
    napi_get_null(env, &n);
    return n;
  }
  unsigned long long total_kb = 0;
  unsigned long long avail_kb = 0;
  char line[256];
  while (fgets(line, sizeof(line), f)) {
    if (sscanf(line, "MemTotal: %llu kB", &total_kb) == 1) {
      continue;
    }
    if (sscanf(line, "MemAvailable: %llu kB", &avail_kb) == 1) {
      continue;
    }
  }
  fclose(f);

  napi_value result, v_total, v_avail;
  napi_create_object(env, &result);
  napi_create_double(env, (double)total_kb * 1024.0, &v_total);
  napi_create_double(env, (double)avail_kb * 1024.0, &v_avail);
  napi_set_named_property(env, result, "totalBytes", v_total);
  napi_set_named_property(env, result, "availableBytes", v_avail);
  if (total_kb > 0 && avail_kb * 100 / total_kb < 10) {
    napi_value pressure;
    napi_create_string_utf8(env, "critical", NAPI_AUTO_LENGTH, &pressure);
    napi_set_named_property(env, result, "pressureLevel", pressure);
  }
  return result;
}

static napi_value Init(napi_env env, napi_value exports) {
  napi_value fn_scan;
  napi_value fn_mem;
  napi_create_function(env, "cursor_proclist_scan_async", NAPI_AUTO_LENGTH,
                       ScanAsync, NULL, &fn_scan);
  napi_create_function(env, "cursor_proclist_system_memory", NAPI_AUTO_LENGTH,
                       SystemMemory, NULL, &fn_mem);
  napi_set_named_property(env, exports, "cursor_proclist_scan_async", fn_scan);
  napi_set_named_property(env, exports, "cursor_proclist_system_memory",
                          fn_mem);
  return exports;
}

NAPI_MODULE(cursor_proclist, Init)
