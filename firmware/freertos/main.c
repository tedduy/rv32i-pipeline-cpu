#include <stdint.h>
void printf(const char *fmt, ...);
#include "FreeRTOS.h"
#include "task.h"

// Defined in system.h but we will just define it here to avoid dependency issue
#define STATUS_REG (*(volatile uint32_t*)0x20000000)

static int task1_count = 0;
static int task2_count = 0;

void vTask1(void *pvParameters) {
    (void)pvParameters;
    for (;;) {
        printf("Task 1 Running (Tick: %d)\n", (int)xTaskGetTickCount());
        task1_count++;
        if (task1_count >= 2 && task2_count >= 2) {
            printf("Context switch test PASS\n");
            STATUS_REG = 1; // End simulation with success
            while(1);
        }
        vTaskDelay(2);
    }
}

void vTask2(void *pvParameters) {
    (void)pvParameters;
    for (;;) {
        printf("Task 2 Running (Tick: %d)\n", (int)xTaskGetTickCount());
        task2_count++;
        vTaskDelay(2);
    }
}

int main(void) {
    printf("Starting FreeRTOS on TDRV32\n");
    
    xTaskCreate(vTask1, "Task1", configMINIMAL_STACK_SIZE, NULL, 1, NULL);
    xTaskCreate(vTask2, "Task2", configMINIMAL_STACK_SIZE, NULL, 1, NULL);
    
    vTaskStartScheduler();
    
    // Should never reach here
    return 0;
}

// FreeRTOS hooks
void vApplicationMallocFailedHook(void) {
    printf("Malloc failed\n");
    for(;;);
}

void vApplicationIdleHook(void) {
    // Idle
}

void vApplicationStackOverflowHook(TaskHandle_t pxTask, char *pcTaskName) {
    (void)pxTask;
    printf("Stack overflow in task %s\n", pcTaskName);
    for(;;);
}

void vApplicationTickHook(void) {
    // Tick
}

// Needed by FreeRTOS port
void freertos_risc_v_application_interrupt_handler(void) {
    // We don't have external interrupts in this demo
}

void freertos_risc_v_application_exception_handler(void) {
    printf("Exception!\n");
    STATUS_REG = 0x100; // End simulation with error
    for(;;);
}
