#include <stdio.h>
#include <string.h>
#include "freertos/FreeRTOS.h"
#include "freertos/task.h"
#include "driver/spi_master.h"
#include "driver/gpio.h"
#include "esp_log.h"
#include "esp_timer.h"

// Pinout XIAO ESP32S3
#define PIN_NUM_MISO 8   // D9
#define PIN_NUM_MOSI 9   // D10
#define PIN_NUM_CLK  7   // D8
#define PIN_NUM_CS   44  // D7

// Registers LSM6DSO
#define CTRL1_XL       0x10
#define CTRL2_G        0x11
#define CTRL3_C        0x12
#define STATUS_REG     0x1E
#define OUTX_L_G       0x22

static const char *TAG = "LSM6DSO";
spi_device_handle_t spi;

esp_err_t lsm6dso_write_reg(uint8_t reg_addr, uint8_t data) {
    spi_transaction_t t = {
        .length = 8,
        .addr = reg_addr & 0x7F,
        .tx_buffer = &data
    };
    return spi_device_polling_transmit(spi, &t);
}

esp_err_t lsm6dso_read_regs(uint8_t reg_addr, uint8_t *data, size_t len) {
    spi_transaction_t t = {
        .length = len * 8,
        .addr = reg_addr | 0x80,
        .rx_buffer = data
    };
    return spi_device_polling_transmit(spi, &t);
}

void imu_init(void) {
    spi_bus_config_t buscfg = {
        .miso_io_num = PIN_NUM_MISO,
        .mosi_io_num = PIN_NUM_MOSI,
        .sclk_io_num = PIN_NUM_CLK,
        .quadwp_io_num = -1,
        .quadhd_io_num = -1,
        .max_transfer_sz = 32
    };

    spi_device_interface_config_t devcfg = {
        .clock_speed_hz = 1000000, 
        .mode = 0,                 
        .spics_io_num = PIN_NUM_CS,
        .queue_size = 7,
        .address_bits = 8,        
        .command_bits = 0,
    };

    ESP_ERROR_CHECK(spi_bus_initialize(SPI2_HOST, &buscfg, SPI_DMA_CH_AUTO));
    ESP_ERROR_CHECK(spi_bus_add_device(SPI2_HOST, &devcfg, &spi));

    lsm6dso_write_reg(CTRL3_C, 0x44); 
    vTaskDelay(1); 
    
    lsm6dso_write_reg(CTRL1_XL, 0x40); // Acc: 104 Hz, +/-2g
    lsm6dso_write_reg(CTRL2_G, 0x40);  // Gyr: 104 Hz, 250 dps
    
    ESP_LOGI(TAG, "Success. LSM6DSO Init.");
}

void imu_task(void *pvParameters) {
    uint8_t status;
    uint8_t data_raw[12];

    while (1) {
        lsm6dso_read_regs(STATUS_REG, &status, 1);
        
        if ((status & 0x03) == 0x03) {
            lsm6dso_read_regs(OUTX_L_G, data_raw, 12);

            int16_t gx = (int16_t)((data_raw[1] << 8) | data_raw[0]);
            int16_t gy = (int16_t)((data_raw[3] << 8) | data_raw[2]);
            int16_t gz = (int16_t)((data_raw[5] << 8) | data_raw[4]);
            int16_t ax = (int16_t)((data_raw[7] << 8) | data_raw[6]);
            int16_t ay = (int16_t)((data_raw[9] << 8) | data_raw[8]);
            int16_t az = (int16_t)((data_raw[11] << 8) | data_raw[10]);
            int64_t timestamp = esp_timer_get_time();

            printf("%lld,%d,%d,%d,%d,%d,%d\n", timestamp, gx, gy, gz, ax, ay, az);
        }
        
        vTaskDelay(1);
    }
}

void app_main(void) {
    imu_init();
    xTaskCreate(imu_task, "imu_task", 4096, NULL, 5, NULL);
}