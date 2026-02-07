# Create Member Edge Function

Denne Edge Function bruges til at oprette nye medlemmer direkte af admin.

## Installation

1. Installer Supabase CLI hvis ikke allerede installeret:
   ```bash
   npm install -g supabase
   ```

2. Log ind på Supabase:
   ```bash
   supabase login
   ```

3. Link dit projekt (erstat med dit projekt ID):
   ```bash
   supabase link --project-ref vzswzajnmubaqghsgqri
   ```

4. Deploy Edge Function:
   ```bash
   supabase functions deploy create-member
   ```

## Brug

Funktionen kaldes automatisk fra Partner Hub når admin opretter et nyt medlem.

Admin angiver:
- Navn
- Email
- Adgangskode

Funktionen:
1. Verificerer at den kaldende bruger er admin i organisationen
2. Opretter en ny bruger med de angivne oplysninger
3. Tilføjer brugeren som medlem af organisationen
4. Sletter eventuelle afventende invitationer for emailen
