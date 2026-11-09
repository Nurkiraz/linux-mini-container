
#define _GNU_SOURCE

#include <stdio.h>
#include <unistd.h>
#include <errno.h>
#include <sys/syscall.h>
#include <seccomp.h>

int main(void) {
    // Filtre uygulanmadan once
    errno = 0;
    long before = syscall(SYS_getppid);

    printf("[1] Filtre ONCESI getppid: %ld\n", before);

    // Varsayilan davranis: izin ver
    scmp_filter_ctx ctx = seccomp_init(SCMP_ACT_ALLOW);

    if (ctx == NULL) {
        perror("seccomp_init");
        return 1;
    }

    // getppid cagrilarina EPERM dondur
    if (seccomp_rule_add(
            ctx,
            SCMP_ACT_ERRNO(EPERM),
            SCMP_SYS(getppid),
            0) < 0) {
        fprintf(stderr, "Kural eklenemedi\n");
        seccomp_release(ctx);
        return 1;
    }

    // Filtreyi kernel'e yukle
    if (seccomp_load(ctx) < 0) {
        fprintf(stderr, "Seccomp filtresi yuklenemedi\n");
        seccomp_release(ctx);
        return 1;
    }

    seccomp_release(ctx);

    // Filtre uygulandiktan sonra
    errno = 0;
    long after = syscall(SYS_getppid);
    int saved_errno = errno;

    printf("[2] Filtre SONRASI getppid: %ld\n", after);
    printf("[3] errno: %d\n", saved_errno);

    if (after == -1 && saved_errno == EPERM) {
        printf("[+] BASARILI: getppid engellendi!\n");
    } else {
        printf("[-] Beklenmeyen sonuc\n");
        return 1;
    }

    return 0;
}
