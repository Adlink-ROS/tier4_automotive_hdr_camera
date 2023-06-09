/*
 * tier4_gw5300.c - tier4_gw5300 ISP driver
 *
 * Copyright (c) 2022-2023, TIER IV Inc.  All rights reserved.
 *
 * This program is free software; you can redistribute it and/or modify it
 * under the terms and conditions of the GNU General Public License,
 * version 2, as published by the Free Software Foundation.
 *
 * This program is distributed in the hope it will be useful, but WITHOUT
 * ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or
 * FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License for
 * more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program.  If not, see <http://www.gnu.org/licenses/>.
 */


#include <linux/module.h>
#include <linux/string.h>
#include <media/camera_common.h>

#include "tier4-gmsl-link.h"
#include "tier4-gw5300.h"

struct tier4_gw5300
{
  struct i2c_client *i2c_client;
  struct gmsl_link_ctx g_client;
  struct mutex lock;
  /* primary ISP properties */
  __u32 def_addr;
};

#define MAX_CHANNEL_NUM 8

#define NO_ERROR 0

/* count channel,the max MAX_CHANNEL_NUM*/
static __u32 channel_count_imx490;

static struct tier4_gw5300 *prim_priv__[MAX_CHANNEL_NUM];

static u8 master_30fps[] = {
  0x33, 0x47, 0x0B, 0x00, 0x00, 0x00, 0x12, 0x00, 0x80, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x17,
};

static u8 master_10fps[] = {
  0x33, 0x47, 0x0B, 0x00, 0x00, 0x00, 0x12, 0x00, 0x80, 0x03, 0x00, 0x00, 0x00, 0x1E, 0x00, 0x00, 0x00, 0x38,
};

static u8 slave_10fps[] = {
  0x33, 0x47, 0x0B, 0x00, 0x00, 0x00, 0x12, 0x00, 0x80, 0x03, 0x00, 0x00, 0x00, 0x28, 0x00, 0x00, 0x00, 0x42,
};

static u8 master_20fps[] = { 0x33, 0x47, 0x0B, 0x00, 0x00, 0x00, 0x12, 0x00, 0x80,
                             0x03, 0x00, 0x00, 0x00, 0x5A, 0x00, 0x00, 0x00, 0x74 };

static u8 slave_20fps[] = { 0x33, 0x47, 0x0B, 0x00, 0x00, 0x00, 0x12, 0x00, 0x80,
                            0x03, 0x00, 0x00, 0x00, 0x5F, 0x00, 0x00, 0x00, 0x79 };

static u8 slave_30fps[] = { 0x33, 0x47, 0x0B, 0x00, 0x00, 0x00, 0x12, 0x00, 0x80,
                            0x03, 0x00, 0x00, 0x00, 0x55, 0x00, 0x00, 0x00, 0x6F };


struct map_ctx
{
  u8 dt;
  u16 addr;
  u8 val;
  u8 st_id;
};

#if 0
static int tier4_gw5300_receive_msg(struct device *dev, u8 *data, int data_size )
{
	int	err = 0;
	struct i2c_msg msg;
	struct tier4_gw5300 *priv = dev_get_drvdata(dev);

	msg.addr = priv->i2c_client->addr;
	msg.flags = I2C_M_RD;			// I2C Read
	msg.len = data_size;
	msg.buf = data;

	err = i2c_transfer(priv->i2c_client->adapter, &msg, 1);

	if (err < 0 ) {
		dev_err(dev, "[%s] : i2c_transer receive message failed : slave addr = 0x%x\n", __func__, msg.addr );
	}

	return err;
}
#endif

static int tier4_gw5300_send_and_recv_msg(struct device *dev, u8 *wdata, int wdata_size, u8 *rdata, int rdata_size)
{
  int err = 0;
  struct i2c_msg msg[2];
  struct tier4_gw5300 *priv = dev_get_drvdata(dev);

  msg[0].addr = priv->i2c_client->addr;
  msg[0].flags = 0;  // I2C Write
  msg[0].len = wdata_size;
  msg[0].buf = wdata;

  msg[1].addr = priv->i2c_client->addr;
  msg[1].flags = I2C_M_RD;  // I2C Read
  msg[1].len = rdata_size;
  msg[1].buf = rdata;

  err = i2c_transfer(priv->i2c_client->adapter, msg, 2);

  if (err < 0)
  {
    dev_err(dev, "[%s] : i2c_transer send message failed. %d: slave addr = 0x%x\n", __func__, err, msg[0].addr);
  }
  else
  {
    dev_dbg(dev, "[%s] : i2c_transer send message. : slave addr = 0x%x\n", __func__, msg[0].addr);
  }

  return err;
}

uint8_t calcCheckSum(const uint8_t *data, size_t size){
    uint8_t result = 0;
    size_t i =0;
      for(i=0; i<size; i++){
	      result += data[i];
      }
      return result;
}

int tier4_gw5300_set_integration_time_on_aemode(struct device *dev, u16 max_integration_time, u16 min_integration_time){
#define MS_TO_LINE_UNIT 80
  u8 	buf[6];
  int ret = 0;
  
  u8 cmd_integration_max[22] = {0x33, 0x47, 0x0f, 0x00, 0x00, 0x00, 0x55, 0x00, 0x80, 0x05, 0x00, 0x15, 0x00, 0x01, 0x00, 0x04, 0x00, 0x70, 0x03, 0x00, 0x00, 0x00}; // val = 0x70, 0x03, 0x00, 0x00
  u8 cmd_integration_min[20] = {0x33, 0x47, 0x0d, 0x00, 0x00, 0x00, 0x55, 0x00, 0x80, 0x05, 0x00, 0x21, 0x00, 0x01, 0x00, 0x02, 0x00, 0x70, 0x03, 0x00}; //val = 0x70, 0x03 
  
  const size_t max_val_pos = 17;
  const size_t min_val_pos = 17;
  uint32_t min_line =  min_integration_time / 1000 * MS_TO_LINE_UNIT;
  uint32_t max_line =  max_integration_time / 1000 * MS_TO_LINE_UNIT;
  uint8_t b1 = max_line &0xFF;
  uint8_t b2 = (max_line >> 8)&0xFF;
  uint8_t b3 = 0;
  uint8_t b4 = 0;
  
  cmd_integration_max[max_val_pos] = b1;
  cmd_integration_max[max_val_pos+1] = b2;
  cmd_integration_max[max_val_pos+2] = b3;
  cmd_integration_max[max_val_pos+3] = b4;
  cmd_integration_max[sizeof(cmd_integration_max)-1] = calcCheckSum(cmd_integration_max, sizeof(cmd_integration_max));


  b1 = min_line &0xFF;
  b2 = (min_line >> 8)&0xFF;

  cmd_integration_min[min_val_pos] = b1;
  cmd_integration_min[min_val_pos+1] = b2;

  cmd_integration_min[sizeof(cmd_integration_min)-1] = calcCheckSum(cmd_integration_min, sizeof(cmd_integration_min));


    msleep(20);
  ret += tier4_gw5300_send_and_recv_msg(dev, cmd_integration_max, sizeof(cmd_integration_max), buf, sizeof(buf));   
    msleep(20);
  ret += tier4_gw5300_send_and_recv_msg(dev, cmd_integration_min, sizeof(cmd_integration_min), buf, sizeof(buf));   

  return ret;

}
EXPORT_SYMBOL(tier4_gw5300_set_integration_time_on_aemode);

int tier4_gw5300_check_device(struct device *dev, u8 *rdata, int rdata_size )
{
  int err = 0;
  struct i2c_msg msg[2];
  struct tier4_gw5300 *priv = dev_get_drvdata(dev);

  msg[0].addr = priv->i2c_client->addr;
  msg[0].flags = I2C_M_RD;  // I2C Read
  msg[0].len = rdata_size;
  msg[0].buf = rdata;

  err = i2c_transfer(priv->i2c_client->adapter, msg, 1);

  if (err <= 0)
  {
    dev_err(dev, "[%s] : i2c_transer send message failed. : slave addr = 0x%x\n", __func__, msg[0].addr);
  }
  else
  {
    dev_dbg(dev, "[%s] : i2c_transer send message. : slave addr = 0x%x\n", __func__, msg[0].addr);
    err = NO_ERROR;
  }

  return err;
}
EXPORT_SYMBOL(tier4_gw5300_check_device);

int tier4_gw5300_prim_slave_addr(struct gmsl_link_ctx *g_ctx)
{
  if (!g_ctx)
  {
    dev_err(&prim_priv__[channel_count_imx490 - 1]->i2c_client->dev, "[%s] : Failed. g_ctx is null\n", __func__);
    return -1;
  }

  g_ctx->sdev_isp_def = prim_priv__[channel_count_imx490 - 1]->def_addr;

  return 0;
}
EXPORT_SYMBOL(tier4_gw5300_prim_slave_addr);

int tier4_gw5300_setup_sensor_mode(struct device *dev, int sensor_mode)
{
  int err = 0;
  u8 buf[6];

  memset(buf, 0x00, 6);

  switch (sensor_mode)
  {
    case GW5300_MASTER_MODE_30FPS:
      err = tier4_gw5300_send_and_recv_msg(dev, master_30fps, sizeof(master_30fps), buf, sizeof(buf));
      if (err < 0)
      {
        dev_err(dev, "[%s] : Setting up Master mode 30fps failed. %d message has been sent to gw5300.\n", __func__,
                err);
        goto error;
      }
      else if (err == 0)
      {  // it means that 0 message has been sent.
        dev_err(dev, "[%s] : Setting up Master mode 30fps failed. %d message has been sent to gw5300.\n", __func__,
                err);
        err = -999;
        goto error;
      }
      else
      {
        err = 0;
      }
      break;

    case GW5300_MASTER_MODE_10FPS:

      err = tier4_gw5300_send_and_recv_msg(dev, master_10fps, sizeof(master_10fps), buf, sizeof(buf));
      if (err < 0)
      {
        dev_err(dev, "[%s] : Setting up Master mode 10fps failed. %d message has been sent to gw5300.\n", __func__,
                err);
        goto error;
      }
      else if (err == 0)
      {  // it means that 0 message has been sent.
        dev_err(dev, "[%s] : Setting up Master mode 10fps failed. %d message has been sent to gw5300.\n", __func__,
                err);
        err = -999;
        goto error;
      }
      else
      {
        err = 0;
      }
      break;

    case GW5300_SLAVE_MODE_10FPS:

      err = tier4_gw5300_send_and_recv_msg(dev, slave_10fps, sizeof(slave_10fps), buf, sizeof(buf));
      if (err < 0)
      {
        dev_err(dev, "[%s] : Setting up Slave mode 10fps failed. %d message has been sent to gw5300.\n", __func__, err);
        goto error;
      }
      else if (err == 0)
      {  // it means that 0 message has been sent.
        dev_err(dev, "[%s] : Setting up Slave mode 10fps failed. %d message has been sent to gw5300.\n", __func__, err);
        err = -999;
        goto error;
      }
      else
      {
        err = 0;
      }
      break;

    case GW5300_SLAVE_MODE_20FPS:
      err = tier4_gw5300_send_and_recv_msg(dev, slave_20fps, sizeof(slave_20fps), buf, sizeof(buf));
      if (err < 0)
      {
        dev_err(dev, "[%s] : Setting up Slave mode 20fps failed. %d message has been sent to gw5300.\n", __func__, err);
        goto error;
      }
      else if (err == 0)
      {  // it means that 0 message has been sent.
        dev_err(dev, "[%s] : Setting up Slave mode 20fps failed. %d message has been sent to gw5300.\n", __func__, err);
        err = -999;
        goto error;
      }
      else
      {
        err = 0;
      }
      break;

    case GW5300_MASTER_MODE_20FPS:
      err = tier4_gw5300_send_and_recv_msg(dev, master_20fps, sizeof(master_20fps), buf, sizeof(buf));
      if (err < 0)
      {
        dev_err(dev, "[%s] : Setting up Master mode 20fps failed. %d message has been sent to gw5300.\n", __func__,
                err);
        goto error;
      }
      else if (err == 0)
      {  // it means that 0 message has been sent.
        dev_err(dev, "[%s] : Setting up Master mode 20fps failed. %d message has been sent to gw5300.\n", __func__,
                err);
        err = -999;
        goto error;
      }
      else
      {
        err = 0;
      }
      break;
    case GW5300_SLAVE_MODE_30FPS:
      err = tier4_gw5300_send_and_recv_msg(dev, slave_30fps, sizeof(slave_30fps), buf, sizeof(buf));
      if (err < 0)
      {
        dev_err(dev, "[%s] : Setting up Slave mode 30fps failed. %d message has been sent to gw5300.\n", __func__, err);
        goto error;
      }
      else if (err == 0)
      {  // it means that 0 message has been sent.
        dev_err(dev, "[%s] : Setting up Slave mode 30fps failed. %d message has been sent to gw5300.\n", __func__, err);
        err = -999;
        goto error;
      }
      else
      {
        err = 0;
      }
      break;
    default:
      break;
  }

error:

  return err;
}
EXPORT_SYMBOL(tier4_gw5300_setup_sensor_mode);


static int tier4_gw5300_probe(struct i2c_client *client,
				const struct i2c_device_id *id)
{
  struct tier4_gw5300 *priv;
  int err = 0;
  struct device_node *node = client->dev.of_node;

  dev_info(&client->dev, "[%s] : probing GW5300 ISP\n", __func__);

  priv = devm_kzalloc(&client->dev, sizeof(*priv), GFP_KERNEL);
  priv->i2c_client = client;

  mutex_init(&priv->lock);

  if (of_get_property(node, "is-prim-isp", NULL))
  {
    if (prim_priv__[channel_count_imx490] && channel_count_imx490 >= MAX_CHANNEL_NUM)
    {
      dev_err(&client->dev, "[%s] : prim-isp already exists\n", __func__);
      return -EEXIST;
    }

    err = of_property_read_u32(node, "reg", &priv->def_addr);
    if (err < 0)
    {
      dev_err(&client->dev, "[%s] : reg not found\n", __func__);
      return -EINVAL;
    }

    dev_dbg(&client->dev, "[%s] :gw5300 priv->def_addr = 0x%0x.\n", __func__, priv->def_addr);

    prim_priv__[channel_count_imx490] = priv;
    channel_count_imx490++;
  }

  dev_set_drvdata(&client->dev, priv);

  /* dev communication gets validated when GMSL link setup is done */
  dev_info(&client->dev, "[%s] :  Probing succeeded\n", __func__);

  return err;
}

static int tier4_gw5300_remove(struct i2c_client *client)
{
  struct tier4_gw5300 *priv;

  if (channel_count_imx490 > 0)
    channel_count_imx490--;

  if (client != NULL)
  {
    priv = dev_get_drvdata(&client->dev);
    mutex_destroy(&priv->lock);
    i2c_unregister_device(client);
    client = NULL;
  }

  return 0;
}

static const struct i2c_device_id tier4_gw5300_id[] = {
  { "tier4_gw5300", 0 },
  {},
};

const struct of_device_id tier4_gw5300_of_match[] = {
  {
      .compatible = "nvidia,tier4_gw5300",
  },
  {},
};
MODULE_DEVICE_TABLE(of, tier4_gw5300_of_match);
MODULE_DEVICE_TABLE(i2c, tier4_gw5300_id);

static struct i2c_driver tier4_gw5300_i2c_driver = {
	.driver = {
		.name = "tier4_gw5300",
		.owner = THIS_MODULE,
	},
	.probe = tier4_gw5300_probe,
	.remove = tier4_gw5300_remove,
	.id_table = tier4_gw5300_id,
};

static int __init tier4_gw5300_init(void)
{
  printk(KERN_INFO "ISP Driver for TIERIV Camera.\n");

  return i2c_add_driver(&tier4_gw5300_i2c_driver);
}

static void __exit tier4_gw5300_exit(void)
{
  i2c_del_driver(&tier4_gw5300_i2c_driver);
}

module_init(tier4_gw5300_init);
module_exit(tier4_gw5300_exit);

MODULE_DESCRIPTION("GW5300 ISP driver tier4_gw5300");
MODULE_AUTHOR("Kohji Iwasaki");
MODULE_LICENSE("GPL v2");
