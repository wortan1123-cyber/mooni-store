/* ใส่ค่า Project URL และ anon/publishable key จาก Supabase
   ห้ามใส่ service_role key ในไฟล์หน้าเว็บเด็ดขาด */
window.MOONI_CONFIG = {
  SUPABASE_URL: "https://YOUR_PROJECT_ID.supabase.co",
  SUPABASE_ANON_KEY: "YOUR_SUPABASE_ANON_OR_PUBLISHABLE_KEY",
  STORE: {
    name: "MOONI",
    bankName: "กรุณาตั้งค่าชื่อธนาคาร",
    bankAccountName: "กรุณาตั้งค่าชื่อบัญชี",
    bankAccountNumber: "กรุณาตั้งค่าเลขบัญชี",
    email: "hello@example.com",
    lineUrl: "#",
    instagramUrl: "#"
  }
};