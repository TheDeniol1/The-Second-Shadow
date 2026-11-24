/*
 * ln2_steam_icons: guarda como PNG los iconos de los logros de Steam.
 *
 * Solo lectura. Usa la steam_api64.dll que ya cargó el juego (SDK 1.46) y no
 * desbloquea ni modifica nada. Lua la carga con package.loadlib(ruta,'*'); al
 * cargarse abre un hilo que espera a Steam, pide cada icono y escribe
 * achievement_icons/<API>.png junto a la DLL. El icono es el que Steam muestra
 * ahora: en color si está desbloqueado y en gris si no. Al terminar escribe
 * achievement_icons/index.txt con una línea "<API>=<1|0>" por logro y "done".
 *
 * Compilación (Tiny C 0.9.27, Windows x64):
 *   tools/native-build/tcc/tcc.exe -shared -Wall -o mods/LN2LocalCoop/scripts/ln2_steam_icons.dll
 *     tools/native-build/ln2_steam_icons.c -lkernel32
 */
#include <windows.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

typedef int32_t HSteamUser;
typedef HSteamUser (*fn_get_user)(void);
typedef void *(*fn_find_iface)(HSteamUser, const char *);
typedef uint32_t (*fn_num)(void *);
typedef const char *(*fn_name)(void *, uint32_t);
typedef int (*fn_icon)(void *, const char *);
typedef unsigned char (*fn_achieved)(void *, const char *, unsigned char *, uint32_t *);
typedef unsigned char (*fn_size)(void *, int, uint32_t *, uint32_t *);
typedef unsigned char (*fn_rgba)(void *, int, uint8_t *, int);

#define MAX_ACH 256
#define MAX_SIDE 512

static char g_dir[MAX_PATH];
static uint32_t g_crc[256];

static void crc_init(void) {
    uint32_t n, k, c;
    for (n = 0; n < 256; n++) {
        c = n;
        for (k = 0; k < 8; k++) c = (c & 1) ? 0xEDB88320u ^ (c >> 1) : c >> 1;
        g_crc[n] = c;
    }
}

static uint32_t crc_update(uint32_t c, const uint8_t *p, size_t n) {
    while (n--) c = g_crc[(c ^ *p++) & 0xFF] ^ (c >> 8);
    return c;
}

static void put32(uint8_t *p, uint32_t v) {
    p[0] = (uint8_t)(v >> 24); p[1] = (uint8_t)(v >> 16); p[2] = (uint8_t)(v >> 8); p[3] = (uint8_t)v;
}

static int chunk(FILE *f, const char *type, const uint8_t *data, uint32_t len) {
    uint8_t head[8], tail[4];
    uint32_t c;
    put32(head, len);
    memcpy(head + 4, type, 4);
    c = crc_update(0xFFFFFFFFu, head + 4, 4);
    if (len) c = crc_update(c, data, len);
    put32(tail, c ^ 0xFFFFFFFFu);
    if (fwrite(head, 1, 8, f) != 8) return 0;
    if (len && fwrite(data, 1, len, f) != len) return 0;
    return fwrite(tail, 1, 4, f) == 4;
}

/* PNG RGBA sin compresión (bloques deflate "stored"). */
static int write_png(const char *path, const uint8_t *rgba, uint32_t w, uint32_t h) {
    static const uint8_t sig[8] = {137, 80, 78, 71, 13, 10, 26, 10};
    uint8_t ihdr[13];
    size_t row = (size_t)w * 4 + 1, raw_len = row * h, blocks, z_len, i, pos, at;
    uint8_t *raw, *z;
    uint32_t a = 1, b = 0;
    FILE *f;
    int ok;

    raw = (uint8_t *)malloc(raw_len);
    if (!raw) return 0;
    for (i = 0; i < h; i++) {
        raw[i * row] = 0;
        memcpy(raw + i * row + 1, rgba + i * (size_t)w * 4, (size_t)w * 4);
    }
    blocks = (raw_len + 65534) / 65535;
    z_len = 2 + blocks * 5 + raw_len + 4;
    z = (uint8_t *)malloc(z_len);
    if (!z) { free(raw); return 0; }
    z[0] = 0x78; z[1] = 0x01;
    at = 2;
    for (pos = 0; pos < raw_len;) {
        size_t n = raw_len - pos;
        if (n > 65535) n = 65535;
        z[at++] = (pos + n == raw_len) ? 1 : 0;
        z[at++] = (uint8_t)(n & 0xFF); z[at++] = (uint8_t)(n >> 8);
        z[at++] = (uint8_t)(~n & 0xFF); z[at++] = (uint8_t)((~n >> 8) & 0xFF);
        memcpy(z + at, raw + pos, n);
        at += n; pos += n;
    }
    for (i = 0; i < raw_len; i++) { a = (a + raw[i]) % 65521; b = (b + a) % 65521; }
    put32(z + at, (b << 16) | a);
    at += 4;

    put32(ihdr, w); put32(ihdr + 4, h);
    ihdr[8] = 8; ihdr[9] = 6; ihdr[10] = 0; ihdr[11] = 0; ihdr[12] = 0;
    f = fopen(path, "wb");
    ok = f != NULL;
    if (ok) ok = fwrite(sig, 1, 8, f) == 8;
    if (ok) ok = chunk(f, "IHDR", ihdr, 13);
    if (ok) ok = chunk(f, "IDAT", z, (uint32_t)at);
    if (ok) ok = chunk(f, "IEND", NULL, 0);
    if (f) fclose(f);
    free(z); free(raw);
    return ok;
}

static int safe_name(const char *s) {
    if (!s || !*s || strlen(s) > 100) return 0;
    for (; *s; s++) {
        char c = *s;
        if (!((c >= 'a' && c <= 'z') || (c >= 'A' && c <= 'Z') || (c >= '0' && c <= '9') || c == '_' || c == '-')) return 0;
    }
    return 1;
}

static void *find_iface(fn_find_iface find, HSteamUser user, const char **versions) {
    void *p = NULL;
    for (; *versions && !p; versions++) p = find(user, *versions);
    return p;
}

static DWORD WINAPI worker(LPVOID unused) {
    static const char *stats_versions[] = {"STEAMUSERSTATS_INTERFACE_VERSION011", "STEAMUSERSTATS_INTERFACE_VERSION012",
                                           "STEAMUSERSTATS_INTERFACE_VERSION010", NULL};
    static const char *utils_versions[] = {"SteamUtils009", "SteamUtils010", "SteamUtils008", NULL};
    static char names[MAX_ACH][104];
    static unsigned char written[MAX_ACH], achieved[MAX_ACH];
    HMODULE steam = NULL;
    fn_get_user get_user; fn_find_iface find; fn_num num; fn_name name; fn_icon icon;
    fn_achieved is_achieved; fn_size size; fn_rgba rgba;
    void *stats = NULL, *utils = NULL;
    uint32_t count = 0, i, done = 0;
    uint8_t *pixels;
    int tries;
    char path[MAX_PATH + 128], tmp[MAX_PATH + 136];
    FILE *f;
    (void)unused;

    /* Espera hasta 3 minutos a que el juego haya iniciado Steam y recibido los logros. */
    for (tries = 0; tries < 360; tries++, Sleep(500)) {
        if (!steam) steam = GetModuleHandleA("steam_api64.dll");
        if (!steam) continue;
        get_user = (fn_get_user)GetProcAddress(steam, "SteamAPI_GetHSteamUser");
        find = (fn_find_iface)GetProcAddress(steam, "SteamInternal_FindOrCreateUserInterface");
        num = (fn_num)GetProcAddress(steam, "SteamAPI_ISteamUserStats_GetNumAchievements");
        name = (fn_name)GetProcAddress(steam, "SteamAPI_ISteamUserStats_GetAchievementName");
        icon = (fn_icon)GetProcAddress(steam, "SteamAPI_ISteamUserStats_GetAchievementIcon");
        is_achieved = (fn_achieved)GetProcAddress(steam, "SteamAPI_ISteamUserStats_GetAchievementAndUnlockTime");
        size = (fn_size)GetProcAddress(steam, "SteamAPI_ISteamUtils_GetImageSize");
        rgba = (fn_rgba)GetProcAddress(steam, "SteamAPI_ISteamUtils_GetImageRGBA");
        if (!(get_user && find && num && name && icon && is_achieved && size && rgba)) return 1;
        if (!get_user()) continue;
        if (!stats) stats = find_iface(find, get_user(), stats_versions);
        if (!utils) utils = find_iface(find, get_user(), utils_versions);
        if (stats && utils && (count = num(stats)) > 0) break;
    }
    if (!count) return 2;
    if (count > MAX_ACH) count = MAX_ACH;
    for (i = 0; i < count; i++) {
        const char *n = name(stats, i);
        names[i][0] = 0;
        if (safe_name(n)) strcpy(names[i], n);
        else written[i] = 1;
    }
    pixels = (uint8_t *)malloc(MAX_SIDE * MAX_SIDE * 4);
    if (!pixels) return 3;

    /* Steam descarga los iconos a demanda: se reintenta hasta 90 segundos. */
    for (tries = 0; tries < 90 && done < count; tries++) {
        done = 0;
        for (i = 0; i < count; i++) {
            int handle;
            uint32_t w = 0, h = 0, t = 0;
            unsigned char got = 0;
            if (written[i]) { done++; continue; }
            handle = icon(stats, names[i]);
            if (handle <= 0) continue;
            if (!size(utils, handle, &w, &h) || !w || !h || w > MAX_SIDE || h > MAX_SIDE) continue;
            if (!rgba(utils, handle, pixels, (int)(w * h * 4))) continue;
            if (is_achieved(stats, names[i], &got, &t)) achieved[i] = got ? 1 : 0;
            sprintf(path, "%s%s.png", g_dir, names[i]);
            sprintf(tmp, "%s.part", path);
            if (write_png(tmp, pixels, w, h) && MoveFileExA(tmp, path, MOVEFILE_REPLACE_EXISTING)) {
                written[i] = 2;
                done++;
            }
        }
        if (done < count) Sleep(1000);
    }
    free(pixels);

    sprintf(path, "%sindex.txt", g_dir);
    sprintf(tmp, "%s.part", path);
    f = fopen(tmp, "w");
    if (!f) return 4;
    for (i = 0; i < count; i++)
        if (written[i] == 2) fprintf(f, "%s=%d\n", names[i], achieved[i]);
    fprintf(f, "done\n");
    fclose(f);
    MoveFileExA(tmp, path, MOVEFILE_REPLACE_EXISTING);
    return 0;
}

BOOL WINAPI DllMain(HINSTANCE instance, DWORD reason, LPVOID reserved) {
    (void)reserved;
    if (reason == DLL_PROCESS_ATTACH) {
        char *slash;
        HANDLE thread;
        DisableThreadLibraryCalls(instance);
        {
            /* Fija la DLL en memoria: si Lua se reinicia y la libera, el hilo seguiría vivo. */
            typedef BOOL (WINAPI *fn_pin)(DWORD, LPCSTR, HMODULE *);
            fn_pin pin = (fn_pin)GetProcAddress(GetModuleHandleA("kernel32.dll"), "GetModuleHandleExA");
            HMODULE self = NULL;
            if (pin) pin(0x1 | 0x4, (LPCSTR)(void *)worker, &self); /* PIN | FROM_ADDRESS */
        }
        if (!GetModuleFileNameA(instance, g_dir, MAX_PATH - 32)) return TRUE;
        slash = strrchr(g_dir, '\\');
        if (!slash) return TRUE;
        strcpy(slash + 1, "achievement_icons\\");
        CreateDirectoryA(g_dir, NULL);
        crc_init();
        thread = CreateThread(NULL, 0, worker, NULL, 0, NULL);
        if (thread) CloseHandle(thread);
    }
    return TRUE;
}
