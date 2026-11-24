#include "main.h"
#include <string.h>
#include <stdio.h>

I2C_HandleTypeDef hi2c1;
UART_HandleTypeDef huart1;

#define BH1750_ADDR   (0x23 << 1) = LIGHT
#define SHT31_ADDR    (0x44 << 1) = TEMP
#define ADS1115_ADDR  (0x48 << 1) = HUMIDITY  

void SystemClock_Config(void);
static void MX_GPIO_Init(void);
static void MX_I2C1_Init(void);
static void MX_USART1_UART_Init(void);

int main(void)
{
  HAL_Init();
  SystemClock_Config();

  MX_GPIO_Init();
  MX_I2C1_Init();
  MX_USART1_UART_Init();

  uint8_t d;
  char message;

  uint8_t cmd_bh  = 0x10;
  uint8_t cmd_sht = {0x24, 0x00};
  uint8_t cfg_ads = {0x01, 0xC2, 0x83};
  uint8_t reg_ads = 0x00;

  HAL_StatusTypeDef ack_bh, ack_sht, ack_ads;

  while (1)
  {
    uint16_t lux = 0, soil = 0;
    int temp = 0, hum = 0;

    /* 1. Check ACK & Receive Data: BH1750 (Light) */
    ack_bh = HAL_I2C_IsDeviceReady(&hi2c1, BH1750_ADDR, 2, 100);
    if (ack_bh == HAL_OK)
    {
      HAL_I2C_Master_Transmit(&hi2c1, BH1750_ADDR, &cmd_bh, 1, 100);
      HAL_Delay(180);
      if (HAL_I2C_Master_Receive(&hi2c1, BH1750_ADDR, d, 2, 100) == HAL_OK)
      {
        lux = ((d << 8) | d) / 1.2;
      }
    }

    /* 2. Check ACK & Receive Data: SHT31 (Temp & Humidity) */
    ack_sht = HAL_I2C_IsDeviceReady(&hi2c1, SHT31_ADDR, 2, 100);
    if (ack_sht == HAL_OK)
    {
      HAL_I2C_Master_Transmit(&hi2c1, SHT31_ADDR, cmd_sht, 2, 100);
      HAL_Delay(20);
      if (HAL_I2C_Master_Receive(&hi2c1, SHT31_ADDR, d, 6, 100) == HAL_OK)
      {
        temp = -45 + (175L * ((d << 8) | d)) / 65535;
        hum  = (100L * ((d << 8) | d)) / 65535;
      }
    }

    /* 3. Check ACK & Receive Data: ADS1115 (Soil Moisture) */
    ack_ads = HAL_I2C_IsDeviceReady(&hi2c1, ADS1115_ADDR, 2, 100);
    if (ack_ads == HAL_OK)
    {
      HAL_I2C_Master_Transmit(&hi2c1, ADS1115_ADDR, cfg_ads, 3, 100);
      HAL_Delay(10);
      HAL_I2C_Master_Transmit(&hi2c1, ADS1115_ADDR, &reg_ads, 1, 100);
      if (HAL_I2C_Master_Receive(&hi2c1, ADS1115_ADDR, d, 2, 100) == HAL_OK)
      {
        soil = (d << 8) | d;
      }
    }

    /* Print Received Data + ACK/NACK Status over UART */
    snprintf(message, sizeof(message),
             "BH1750[%s]:%u lx | SHT31[%s]:%dC,%d%% | ADS[%s]:%u\r\n",
             (ack_bh  == HAL_OK) ? "ACK" : "NACK", lux,
             (ack_sht == HAL_OK) ? "ACK" : "NACK", temp, hum,
             (ack_ads == HAL_OK) ? "ACK" : "NACK", soil);

    HAL_UART_Transmit(&huart1, (uint8_t*)message, strlen(message), HAL_MAX_DELAY);

    /* Pump Control (Only triggers if ADS1115 ACKed and soil is dry) */
    if (ack_ads == HAL_OK && soil > 20000)
      HAL_GPIO_WritePin(GPIOA, GPIO_PIN_5, GPIO_PIN_SET);
    else
      HAL_GPIO_WritePin(GPIOA, GPIO_PIN_5, GPIO_PIN_RESET);

    HAL_Delay(2000);
  }
}
