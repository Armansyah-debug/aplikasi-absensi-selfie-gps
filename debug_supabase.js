const { createClient } = require('@supabase/supabase-js');

const supabaseUrl = 'https://vqeedgzeamkzkxrrautk.supabase.co';
const supabaseKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InZxZWVkZ3plYW1remt4cnJhdXRrIiwicm9sZSI6ImFub24iLCJpYXQiOjE3Njc1NjM2NzMsImV4cCI6MjA4MzEzOTY3M30.OFOvsB5UaFAT52ZGlS9cW8X5bglXT1WhSG_s7B_LR3c';
const supabase = createClient(supabaseUrl, supabaseKey);

async function debugQuery() {
    console.log('--- MENCARI USER ID DARI DATA TERAKHIR ---');
    const { data: latestData, error: latestError } = await supabase
        .from('data_absensi')
        .select('user_id')
        .limit(1)
        .order('waktu', { ascending: false });

    if (latestError) {
        console.error('ERROR MENCARI USER:', latestError);
        return;
    }

    if (!latestData || latestData.length === 0) {
        console.log('Tabel data_absensi KOSONG.');
        return;
    }

    const userId = latestData[0].user_id;
    console.log('USER ID DITEMUKAN:', userId);

    console.log('\n--- MENCOBA QUERY JOIN ---');
    const { data: joinData, error: joinError } = await supabase
        .from('data_absensi')
        .select(`
            *,
            sesi_absensi(
                mata_kuliah(
                    nama_mk
                )
            )
        `)
        .eq('user_id', userId)
        .order('waktu', { ascending: false });

    if (joinError) {
        console.log('DEBUG getMyHistoryWithMK error:', joinError.message);
        console.log('DETAILS:', joinError.details);
        console.log('HINT:', joinError.hint);
    } else {
        console.log('DEBUG getMyHistoryWithMK result:', JSON.stringify(joinData, null, 2));
        console.log('DEBUG getMyHistoryWithMK count:', joinData.length);
        if (joinData.length > 0) {
            console.log('\nDATA PERTAMA (Index 0):', JSON.stringify(joinData[0], null, 2));
        }
    }

    if (!joinData || joinData.length === 0) {
        console.log('\n--- MENCOBA QUERY TANPA JOIN ---');
        const { data: simpleData } = await supabase
            .from('data_absensi')
            .select('*')
            .eq('user_id', userId)
            .limit(5);
        console.log('Hasil tanpa join (limit 5):', JSON.stringify(simpleData, null, 2));
    }
}

debugQuery();
