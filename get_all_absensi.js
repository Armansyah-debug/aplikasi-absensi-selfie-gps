const https = require('https');

const options = {
  headers: {
    'apikey': 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InZxZWVkZ3plYW1remt4cnJhdXRrIiwicm9sZSI6ImFub24iLCJpYXQiOjE3Njc1NjM2NzMsImV4cCI6MjA4MzEzOTY3M30.OFOvsB5UaFAT52ZGlS9cW8X5bglXT1WhSG_s7B_LR3c',
    'Authorization': 'Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InZxZWVkZ3plYW1remt4cnJhdXRrIiwicm9sZSI6ImFub24iLCJpYXQiOjE3Njc1NjM2NzMsImV4cCI6MjA4MzEzOTY3M30.OFOvsB5UaFAT52ZGlS9cW8X5bglXT1WhSG_s7B_LR3c'
  }
};

const url = 'https://vqeedgzeamkzkxrrautk.supabase.co/rest/v1/data_absensi?select=*';

https.get(url, options, (res) => {
  let data = '';
  res.on('data', (chunk) => data += chunk);
  res.on('end', () => {
    console.log('ALL DATA ABSENSI:', data);
  });
});
