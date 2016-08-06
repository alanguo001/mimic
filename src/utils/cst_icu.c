/*
 * icu functions
 * 
 * Copyright 2016 Sergio Oller <sergioller@gmail.com>

 * Redistribution and use in source and binary forms, with or without
 * modification, are permitted provided that the following conditions are
 * met:
 * 
 * * Redistributions of source code must retain the above copyright
 *   notice, this list of conditions and the following disclaimer.
 * * Redistributions in binary form must reproduce the above
 *   copyright notice, this list of conditions and the following disclaimer
 *   in the documentation and/or other materials provided with the
 *   distribution.
 * * Neither the name of the  nor the names of its
 *   contributors may be used to endorse or promote products derived from
 *   this software without specific prior written permission.
 * 
 * THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS
 * "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT
 * LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR
 * A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT
 * OWNER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL,
 * SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT
 * LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE,
 * DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY
 * THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
 * (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE
 * OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 * 
 */

#include <stdint.h>
#include <unicode/ustring.h>
#include <unicode/ucasemap.h>
#include "cst_icu.h"
#include "cst_alloc.h"
#include "cst_string.h"

cst_string* cst_tolower(const cst_string *in, const char *locale)
{
	cst_string* lowered = NULL;
	int32_t lower_size;
	UCaseMap* csm;
	UErrorCode status = U_ZERO_ERROR;
	csm = ucasemap_open(locale, 0, &status);
	lower_size = ucasemap_utf8ToLower(csm, NULL, 0, in, -1, &status);
	lowered = cst_alloc(char, lower_size + 1);
	ucasemap_utf8ToLower(csm, lowered, lower_size + 1, in, -1, &status);
	ucasemap_close(csm);
	return lowered;
}

