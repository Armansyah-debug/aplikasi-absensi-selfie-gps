const https = require('https');

const options = {
  method: 'POST',
  headers: {
    'apikey': 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InZxZWVkZ3plYW1remt4cnJhdXRrIiwicm9sZSI6ImFub24iLCJpYXQiOjE3Njc1NjM2NzMsImV4cCI6MjA4MzEzOTY3M30.OFOvsB5UaFAT52ZGlS9cW8X5bglXT1WhSG_s7B_LR3c',
    'Authorization': 'Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InZxZWVkZ3plYW1remt4cnJhdXRrIiwicm9sZSI6ImFub24iLCJpYXQiOjE3Njc1NjM2NzMsImV4cCI6MjA4MzEzOTY3M30.OFOvsB5UaFAT52ZGlS9cW8X5bglXT1WhSG_s7B_LR3c',
    'Content-Type': 'application/json'
  }
};

// Query untuk melihat RLS Policies
const sql = `
SELECT 
    policyname, 
    cmd, 
    qual as using_clause, 
    with_check 
FROM pg_policies 
WHERE tablename = 'data_absensi';
`;

const body = JSON.stringify({ query: sql });

const req = https.request('https://vqeedgzeamkzkxrrautk.supabase.co/rest/v1/rpc/get_policies', options, (res) => {
  let data = '';
  res.on('data', (chunk) => data += chunk);
  res.on('end', () => {
    console.log('--- RLS POLICIES FOR data_absensi ---');
    console.log(data);
  });
});

req.on('error', (err) => {
  // Jika RPC tidak ada, coba cara lain via informasi skema jika diizinkan
  console.log('Error / RPC get_policies not found. Please check dashboard settings for RLS.');
});

req.write(body);
req.end();
