const https = require('https');

const url = 'https://vqeedgzeamkzkxrrautk.supabase.co/rest/v1/data_absensi?select=user_id&limit=1';
const options = {
  headers: {
    'apikey': 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InZxZWVkZ3plYW1remt4cnJhdXRrIiwicm9sZSI6ImFub24iLCJpYXQiOjE3Njc1NjM2NzMsImV4cCI6MjA4MzEzOTY3M30.OFOvsB5UaFAT52ZGlS9cW8X5bglXT1WhSG_s7B_LR3c',
    'Authorization': 'Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InZxZWVkZ3plYW1remt4cnJhdXRrIiwicm9sZSI6ImFub24iLCJpYXQiOjE3Njc1NjM2NzMsImV4cCI6MjA4MzEzOTY3M30.OFOvsB5UaFAT52ZGlS9cW8X5bglXT1WhSG_s7B_LR3c'
  }
};

https.get(url, options, (res) => {
  let data = '';
  res.on('data', (chunk) => data += chunk);
  res.on('end', () => {
    console.log('USER_ID_RESULT:', data);
    try {
      const json = JSON.parse(data);
      if (json.length > 0) {
        const userId = json[0].user_id;
        runJoinQuery(userId);
      } else {
        console.log('Tabel data_absensi kosong.');
      }
    } catch (e) {
      console.log('Parse error:', e);
    }
  });
}).on('error', (err) => {
  console.log('Error:', err.message);
});

function runJoinQuery(userId) {
  const joinUrl = `https://vqeedgzeamkzkxrrautk.supabase.co/rest/v1/data_absensi?select=*,sesi_absensi(mata_kuliah(nama_mk))&user_id=eq.${userId}&order=waktu.desc`;
  https.get(joinUrl, options, (res) => {
    let data = '';
    res.on('data', (chunk) => data += chunk);
    res.on('end', () => {
      console.log('\n--- RESULT JOIN QUERY ---');
      console.log(data);
    });
  });
}
