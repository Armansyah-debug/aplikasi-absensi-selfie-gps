const { createClient } = require('@supabase/supabase-js');

const supabaseUrl = 'https://vqeedgzeamkzkxrrautk.supabase.co';
const supabaseKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InZxZWVkZ3plYW1remt4cnJhdXRrIiwicm9sZSI6ImFub24iLCJpYXQiOjE3Njc1NjM2NzMsImV4cCI6MjA4MzEzOTY3M30.OFOvsB5UaFAT52ZGlS9cW8X5bglXT1WhSG_s7B_LR3c';
const supabase = createClient(supabaseUrl, supabaseKey);

async function inspectTables() {
    const tables = ['profiles', 'mata_kuliah'];
    
    for (const table of tables) {
        console.log(`\n--- INSPECTING TABLE: ${table} ---`);
        const { data, error } = await supabase
            .from(table)
            .select('*')
            .limit(1);
            
        if (error) {
            console.error(`Error fetching from ${table}:`, error.message);
            continue;
        }
        
        if (data && data.length > 0) {
            const row = data[0];
            console.log('Columns found from sample row:');
            Object.keys(row).forEach(col => {
                console.log(`- ${col} (Value: ${row[col]}, Type guess: ${typeof row[col]})`);
            });
        } else {
            console.log(`Table ${table} is empty. Cannot infer columns from data.`);
            // Try to get at least one column by selecting something common
            const { data: colData, error: colError } = await supabase
                .from(table)
                .select('*')
                .limit(0);
            if (!colError) {
                // In some cases, select * with limit 0 might still give us headers if we use a different client, 
                // but supabase-js might not expose them if data is empty.
            }
        }
    }
}

inspectTables();
