###
  Copyright (c) 2014 clowwindy
  
  Permission is hereby granted, free of charge, to any person obtaining a copy
  of this software and associated documentation files (the "Software"), to deal
  in the Software without restriction, including without limitation the rights
  to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
  copies of the Software, and to permit persons to whom the Software is
  furnished to do so, subject to the following conditions:
  
  The above copyright notice and this permission notice shall be included in
  all copies or substantial portions of the Software.
  
  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
  IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
  FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
  AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
  LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
  OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
  SOFTWARE.
###

crypto = require("crypto")
util = require("util")

bytes_to_key_results = {}

EVP_BytesToKey = (password, key_len, iv_len) ->
  if bytes_to_key_results["#{password}:#{key_len}:#{iv_len}"]
    return bytes_to_key_results["#{password}:#{key_len}:#{iv_len}"]
  m = []
  i = 0
  count = 0
  while count < key_len + iv_len
    md5 = crypto.createHash('md5')
    data = password
    if i > 0
      data = Buffer.concat([m[i - 1], password])
    md5.update(data)
    d = md5.digest()
    m.push(d)
    count += d.length
    i += 1
  ms = Buffer.concat(m)
  key = ms.slice(0, key_len)
  iv = ms.slice(key_len, key_len + iv_len)
  bytes_to_key_results[password] = [key, iv]
  return [key, iv]


method_supported =
  'aes-128-cfb': [16, 16]
  'aes-256-cfb': [32, 16]
  'aes-128-ctr': [16, 16]
  'aes-256-ctr': [32, 16]


class Encryptor
  constructor: (@key, @method) ->
    @iv_sent = false
    @cipher = @get_cipher(@key, @method, 1, crypto.randomBytes(32))
      
  get_cipher_len: (method) ->
    method = method.toLowerCase()
    m = method_supported[method]
    return m

  get_cipher: (password, method, op, iv) ->
    method = method.toLowerCase()
    password = new Buffer(password, 'binary')
    m = @get_cipher_len(method)
    if m?
      [key, iv_] = EVP_BytesToKey(password, m[0], m[1])
      if not iv?
        iv = iv_
      if op == 1
        @cipher_iv = iv.slice(0, m[1])
      iv = iv.slice(0, m[1])
      if op == 1
        return crypto.createCipheriv(method, key, iv)
      else
        return crypto.createDecipheriv(method, key, iv)

  encrypt: (buf) ->
    result = @cipher.update buf
    if @iv_sent
      return result
    else
      @iv_sent = true
      return Buffer.concat([@cipher_iv, result])
      
  decrypt: (buf) ->
    if not @decipher?
      decipher_iv_len = @get_cipher_len(@method)[1]
      decipher_iv = buf.slice(0, decipher_iv_len) 
      @decipher = @get_cipher(@key, @method, 0, decipher_iv)
      result = @decipher.update(buf.slice(decipher_iv_len))
      return result
    else
      result = @decipher.update(buf)
      return result

encryptAll = (password, method, op, data) ->
  result = []
  method = method.toLowerCase()
  [keyLen, ivLen] = method_supported[method]
  password = Buffer(password, 'binary')
  [key, iv_] = EVP_BytesToKey(password, keyLen, ivLen) 
  if op == 1
    iv = crypto.randomBytes ivLen
    result.push iv
    cipher = crypto.createCipheriv(method, key, iv)
  else
    iv = data.slice 0, ivLen
    data = data.slice ivLen
    cipher = crypto.createDecipheriv(method, key, iv)
  result.push cipher.update(data)
  result.push cipher.final()
  return Buffer.concat result


exports.Encryptor = Encryptor
exports.encryptAll = encryptAll

