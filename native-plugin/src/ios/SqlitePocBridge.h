#pragma once

#ifdef __cplusplus
extern "C" {
#endif

// The caller must release the returned UTF-8 JSON using sqlitePocFree.
char *sqlitePocRun(const char *path);
void sqlitePocFree(char *result);

#ifdef __cplusplus
}
#endif
