const https = require('https');

const options = {
  headers: {
    'apikey': 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InZxZWVkZ3plYW1remt4cnJhdXRrIiwicm9sZSI6ImFub24iLCJpYXQiOjE3Njc1NjM2NzMsImV4cCI6MjA4MzEzOTY3M30.OFOvsB5UaFAT52ZGlS9cW8X5bglXT1WhSG_s7B_LR3c',
    'Authorization': 'Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InZxZWVkZ3plYW1remt4cnJhdXRrIiwicm9sZSI6ImFub24iLCJpYXQiOjE3Njc1NjM2NzMsImV4cCI6MjA4MzEzOTY3M30.OFOvsB5UaFAT52ZGlS9cW8X5bglXT1WhSG_s7B_LR3c'
  }
};

function testJoin(tableName, joinSelect) {
  const url = `https://vqeedgzeamkzkxrrautk.supabase.co/rest/v1/${tableName}?select=${joinSelect}&limit=1`;
  https.get(url, options, (res) => {
    let data = '';
    res.on('data', (chunk) => data += chunk);
    res.on('end', () => {
      console.log(`\n--- JOIN TEST ${tableName} -> ${joinSelect} ---`);
      console.log(`Status: ${res.statusCode}`);
      try {
        const json = JSON.parse(data);
        console.log(JSON.stringify(json, null, 2));
      } catch (e) {
        console.log('Error parsing JSON:', e.message);
        console.log('Raw output:', data);
      }
    });
  }).on('error', (err) => {
    console.log(`Error testing join on ${tableName}:`, err.message);
  });
}

// Test if mata_kuliah has a relationship with profiles (via dosen_id)
testJoin('mata_kuliah', '*,profiles(*)');

// Also check if data_absensi has relations to verify my logic
testJoin('data_absensi', '*,profiles(*),sesi_absensi(*)');
