# Alos Hashachar Calculator

A modern Next.js application to display Alos Hashachar (dawn) times according to all calculation methods available in the kosher-zmanim library.

## Features

- **18+ Calculation Methods**: Display all Alos Hashachar times side-by-side
- **Location Input**: Manual latitude/longitude entry or geolocation
- **Date Selection**: Choose any date to calculate times
- **Method Explanations**: Detailed descriptions and halachic sources for each method
- **Modern Design**: Vibrant, responsive UI with Tailwind CSS
- **Categorized Display**: Methods organized by type (Fixed Time, Proportional Hours, Solar Angles)

## Technology Stack

- **Framework**: Next.js 14 with TypeScript
- **Zmanim Library**: kosher-zmanim (TypeScript port of KosherJava)
- **Styling**: Tailwind CSS
- **Date/Time**: Luxon (included with kosher-zmanim)

## Getting Started

### Prerequisites

- Node.js 18+ and npm

### Installation

```bash
# Install dependencies
npm install
```

### Development

```bash
# Run development server
npm run dev
```

Open [http://localhost:3000](http://localhost:3000) in your browser.

### Production Build

```bash
# Build for production
npm run build

# Start production server
npm start
```

### Type Checking

```bash
# Run TypeScript type checking
npm run type-check
```

## Project Structure

```
├── app/
│   ├── globals.css          # Global styles and design system
│   ├── layout.tsx            # Root layout component
│   └── page.tsx              # Main application page
├── components/
│   ├── DatePicker.tsx        # Date selection component
│   ├── LocationInput.tsx     # Location input component
│   ├── MethodCard.tsx        # Individual method display card
│   └── ZmanimDisplay.tsx     # Main results display component
├── lib/
│   ├── constants.ts          # Application constants
│   ├── location.ts           # Location utilities
│   └── zmanim.ts             # Zmanim calculation utilities
├── next.config.js            # Next.js configuration
├── tailwind.config.ts        # Tailwind CSS configuration
└── tsconfig.json             # TypeScript configuration
```

## Calculation Methods

### Fixed Time Before Sunrise
- Alos 60 Minutes
- Alos 72 Minutes (Magen Avraham)
- Alos 90 Minutes
- Alos 96 Minutes
- Alos 120 Minutes

### Proportional Hours (Zmaniyos)
- Alos 72 Zmaniyos (1/10th of day)
- Alos 90 Zmaniyos (1/8th of day)
- Alos 96 Zmaniyos (1/7.5th of day)

### Solar Depression Angles
- Alos 16.1°
- Alos 18° (Astronomical dawn)
- Alos 19°
- Alos 19.8°
- Alos 26°

## Usage

1. **Set Location**: Enter latitude/longitude manually or use "Use My Location" button
2. **Select Date**: Choose a date using the date picker or click "Today"
3. **View Results**: All calculation methods are displayed in categorized cards
4. **Expand Details**: Click on any method card to see detailed explanation and source

## Contributing

This is a demonstration application. For production use, consider:
- Adding more zmanim calculations
- Implementing user preferences storage
- Adding calendar view
- Including shaos zmaniyos calculations
- Adding print functionality

## Halachic Disclaimer

Times are calculated based on astronomical and halachic methods. Consult your local rabbi for practical halachic guidance.

## License

This project is for educational purposes.

## Acknowledgments

- Powered by [kosher-zmanim](https://github.com/BehindTheMath/KosherZmanim) - TypeScript port of KosherJava
- Original KosherJava library by Eliyahu Hershfeld
