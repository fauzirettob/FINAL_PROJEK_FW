const sharp = require('sharp');
sharp('assets/images/bg.png')
  .resize(800)
  .png({ compressionLevel: 9, palette: true })
  .toFile('assets/images/bg_opt.png')
  .then(() => console.log('✅ Optimized successfully'))
  .catch(err => console.error('❌ Error:', err.message));
