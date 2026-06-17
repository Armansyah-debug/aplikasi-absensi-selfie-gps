const https = require('https');

const options = {
  headers: {
    'apikey': 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InZxZWVkZ3plYW1remt4cnJhdXRrIiwicm9sZSI6ImFub24iLCJpYXQiOjE3Njc1NjM2NzMsImV4cCI6MjA4MzEzOTY3M30.OFOvsB5UaFAT52ZGlS9cW8X5bglXT1WhSG_s7B_LR3c',
    'Authorization': 'Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InZxZWVkZ3plYW1remt4cnJhdXRrIiwicm9sZSI6ImFub24iLCJpYXQiOjE3Njc1NjM2NzMsImV4cCI6MjA4MzEzOTY3M30.OFOvsB5UaFAT52ZGlS9cW8X5bglXT1WhSG_s7B_LR3c'
  }
};

function checkTable(tableName) {
  const url = `https://vqeedgzeamkzkxrrautk.supabase.co/rest/v1/${tableName}?select=count`;
  https.get(url, { ...options, headers: { ...options.headers, 'Prefer': 'count=exact' } }, (res) => {
    console.log(`Table ${tableName} status: ${res.statusCode}`);
    let data = '';
    res.on('data', (chunk) => data += chunk);
    res.on('end', () => {
       console.log(`Table ${tableName} count:`, res.headers['content-range']);
    });
  });
}

checkTable('data_absensi');
checkTable('mata_kuliah');
checkTable('sesi_absensi');
checkTable('profiles');
