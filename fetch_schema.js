const https = require('https');
const fs = require('fs');

const options = {
  headers: {
    'apikey': 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InZxZWVkZ3plYW1remt4cnJhdXRrIiwicm9sZSI6ImFub24iLCJpYXQiOjE3Njc1NjM2NzMsImV4cCI6MjA4MzEzOTY3M30.OFOvsB5UaFAT52ZGlS9cW8X5bglXT1WhSG_s7B_LR3c'
  }
};

https.get('https://vqeedgzeamkzkxrrautk.supabase.co/rest/v1/', options, (res) => {
  let data = '';
  res.on('data', (chunk) => data += chunk);
  res.on('end', () => {
    fs.writeFileSync('openapi.json', data);
    console.log('OpenAPI spec saved to openapi.json');
    
    try {
        const spec = JSON.parse(data);
        const tables = ['profiles', 'mata_kuliah'];
        
        tables.forEach(table => {
            console.log(`\n--- SCHEMA FOR ${table} ---`);
            const definition = spec.definitions[table];
            if (definition) {
                console.log('Columns:');
                Object.keys(definition.properties).forEach(prop => {
                    const info = definition.properties[prop];
                    console.log(`- ${prop}: ${info.type} ${info.format ? `(${info.format})` : ''} ${info.description ? `// ${info.description}` : ''}`);
                });
                
                if (definition.required) {
                    console.log('Required columns:', definition.required);
                }
            } else {
                console.log(`Definition for ${table} not found in OpenAPI spec.`);
            }
        });
    } catch (e) {
        console.error('Failed to parse JSON:', e.message);
    }
  });
}).on('error', (err) => {
  console.error('Error fetching OpenAPI spec:', err.message);
});
