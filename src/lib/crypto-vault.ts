import crypto from 'crypto';

const ALGORITHM = 'aes-256-gcm';
const SECRET_KEY = Buffer.from(
  process.env.VAULT_SECRET_KEY || '0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef',
  'hex'
);

export function encryptPassword(plainText: string): string {
  const iv = crypto.randomBytes(12);
  const cipher = crypto.createCipheriv(ALGORITHM, SECRET_KEY, iv);
  const encrypted = Buffer.concat([cipher.update(plainText, 'utf8'), cipher.final()]);
  const authTag = cipher.getAuthTag();
  return `${iv.toString('hex')}:${authTag.toString('hex')}:${encrypted.toString('hex')}`;
}

export function decryptPassword(cipherText: string): string {
  const [ivHex, authTagHex, encryptedHex] = cipherText.split(':');
  const iv = Buffer.from(ivHex, 'hex');
  const authTag = Buffer.from(authTagHex, 'hex');
  const encryptedText = Buffer.from(encryptedHex, 'hex');
  const decipher = crypto.createDecipheriv(ALGORITHM, SECRET_KEY, iv);
  decipher.setAuthTag(authTag);
  const decrypted = Buffer.concat([decipher.update(encryptedText), decipher.final()]);
  return decrypted.toString('utf8');
}

export function generateStrongVaultPassword(): string {
  return `Vault#${crypto.randomBytes(4).toString('hex')}!9A`;
}
