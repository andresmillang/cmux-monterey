#include <stdarg.h>
#include <stdio.h>
#include <stdlib.h>

namespace std {
inline namespace __1 {

__attribute__((noreturn)) void __libcpp_verbose_abort(char const* format, ...) {
    va_list args;
    va_start(args, format);
    if (format != NULL) {
        vfprintf(stderr, format, args);
    }
    va_end(args);

    abort();
}

} // namespace __1
} // namespace std
