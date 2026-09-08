# HumSukhan Website

Accessibility communication platform website deployed on Vercel.

## Structure

- `public/` - Static HTML files and assets
- `vercel.json` - Vercel deployment configuration

## Deployment

This site is configured to deploy on [Vercel](https://vercel.com).

### To Deploy:

1. Connect this GitHub repository to Vercel
2. Vercel will automatically detect and deploy `public/` directory
3. Any push to main branch triggers automatic redeploy

### Adding Your Content:

Replace or add HTML files to the `public/` directory:
- `public/index.html` - Homepage (currently placeholder)
- `public/css/` - Stylesheets
- `public/js/` - JavaScript files
- `public/images/` - Image assets

## Local Testing

Simply open `public/index.html` in your browser to preview.

For development with a local server:
```bash
# Using Python 3
python -m http.server 8000

# Using Node.js
npx http-server public
```

Then visit `http://localhost:8000`
