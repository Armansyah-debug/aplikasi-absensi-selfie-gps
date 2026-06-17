const https = require('https');

const options = {
  headers: {
    'apikey': 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InZxZWVkZ3plYW1remt4cnJhdXRrIiwicm9sZSI6ImFub24iLCJpYXQiOjE3Njc1NjM2NzMsImV4cCI6MjA4MzEzOTY3M30.OFOvsB5UaFAT52ZGlS9cW8X5bglXT1WhSG_s7B_LR3c',
    'Authorization': 'Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InZxZWVkZ3plYW1remt4cnJhdXRrIiwicm9sZSI6ImFub24iLCJpYXQiOjE3Njc1NjM2NzMsImV4cCI6MjA4MzEzOTY3M30.OFOvsB5UaFAT52ZGlS9cW8X5bglXT1WhSG_s7B_LR3c'
  }
};

function fetchTableInfo(tableName) {
  const url = `https://vqeedgzeamkzkxrrautk.supabase.co/rest/v1/${tableName}?select=*&limit=1`;
  https.get(url, options, (res) => {
    let data = '';
    res.on('data', (chunk) => data += chunk);
    res.on('end', () => {
      console.log(`\n--- ${tableName.toUpperCase()} ---`);
      try {
        const json = JSON.parse(data);
        if (json.length > 0) {
          console.log(JSON.stringify(json[0], null, 2));
        } else {
          console.log('Empty table');
        }
      } catch (e) {
        console.log('Error parsing JSON:', e.message);
        console.log('Raw output:', data);
      }
    });
  }).on('error', (err) => {
    console.log(`Error fetching ${tableName}:`, err.message);
  });
}

fetchTableInfo('profiles');
fetchTableInfo('mata_kuliah');
