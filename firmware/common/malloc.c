#include <stdint.h>

// A tiny static allocator for Dhrystone (only needs 2 structs)
#define HEAP_SIZE 1024
static char heap[HEAP_SIZE];
static int heap_ptr = 0;

void *malloc(int size) {
    if (heap_ptr + size > HEAP_SIZE) return 0;
    void *ptr = &heap[heap_ptr];
    heap_ptr += size;
    return ptr;
}
