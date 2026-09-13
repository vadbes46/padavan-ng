/* SPDX-License-Identifier: GPL-2.0 */
#ifndef _AWG_HEADER_PROTECTION
#define _AWG_HEADER_PROTECTION

#include <linux/types.h>
#include <linux/rwsem.h>

struct wg_device;

enum header_protection_lengths {
	HEADER_PROTECTION_KEY_SIZE = 32,
	HEADER_PROTECTION_NONCE_SIZE = 12,
};

struct chacha_state {
	u32 x[16];
};

struct header_protection {
	u32 key[8];
	struct rw_semaphore lock;
	bool has_protection;
};

bool awg_header_protection_init(struct chacha_state *state, struct wg_device *dev, u8 *nonce);
void awg_header_protection_set_key(struct header_protection *p, const u8 key[HEADER_PROTECTION_KEY_SIZE]);
void awg_header_protection_get_key(struct header_protection *p, u8 key[HEADER_PROTECTION_KEY_SIZE]);
void chacha20_crypt(struct chacha_state *state, u8 *dst, const u8 *src, unsigned int bytes);

#endif /* _AWG_HEADER_PROTECTION */
