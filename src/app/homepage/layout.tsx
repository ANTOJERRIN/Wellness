import { SiteFooter } from '@/components/site-footer';
import { SiteHeader } from '@/components/site-header';
import { Toaster } from '@/components/ui/toaster';
import { ThemeProvider } from '@/hooks/use-theme';
import { Analytics } from '@vercel/analytics/react';
import { GeistMono } from 'geist/font/mono';
import { GeistSans } from 'geist/font/sans';
import type { Metadata } from 'next';
import { AOSProvider } from '@/components/aos-provider';
import { StructuredData } from '../structured-data';

const geistSans = GeistSans;
const geistMono = GeistMono;

export const metadata: Metadata = {
  title: {
    default: 'Wellness - Your AI Health Assistant',
    template: '%s | Wellness',
  },
  description:
    'Get instant AI-powered health advice and medical information. Ask questions about symptoms, treatments, and general health guidance with our intelligent medical chatbot.',
  keywords: [
    'AI health assistant',
    'medical chatbot',
    'health advice',
    'symptoms checker',
    'medical information',
    'healthcare AI',
    'virtual health assistant',
    'medical consultation',
    'health questions',
    'AI doctor',
  ],
  authors: [{ name: 'Wellness Team' }],
  creator: 'Wellness',
  publisher: 'Wellness',
  formatDetection: {
    email: false,
    address: false,
    telephone: false,
  },
  metadataBase: new URL('https://wellness-five.vercel.app'),
  alternates: {
    canonical: '/',
  },
  openGraph: {
    type: 'website',
    locale: 'en_US',
    url: 'https://wellness-five.vercel.app',
    title: 'Wellness - Your AI Health Assistant',
    description:
      'Get instant AI-powered health advice and medical information. Ask questions about symptoms, treatments, and general health guidance.',
    siteName: 'Wellness',
    images: [
      {
        url: 'https://wellness-five.vercel.app/og-image.png',
        width: 1200,
        height: 630,
        alt: 'Wellness - AI Health Assistant',
      },
    ],
  },
  twitter: {
    card: 'summary_large_image',
    title: 'Wellness - Your AI Health Assistant',
    description:
      'Get instant AI-powered health advice and medical information. Ask questions about symptoms, treatments, and general health guidance.',
    images: ['https://wellness-five.vercel.app/og-image.png'],
    creator: '@wellness',
    site: '@wellness',
  },
  robots: {
    index: true,
    follow: true,
    googleBot: {
      index: true,
      follow: true,
      'max-video-preview': -1,
      'max-image-preview': 'large',
      'max-snippet': -1,
    },
  },
  verification: {
    google: 'your-google-verification-code', // Replace with actual verification code
    yandex: 'your-yandex-verification-code',
    yahoo: 'your-yahoo-verification-code',
  },
  category: 'health',
  classification: 'healthcare',
  other: {
    'msapplication-TileColor': '#ffffff',
    'theme-color': '#ffffff',
    'apple-mobile-web-app-capable': 'yes',
    'apple-mobile-web-app-status-bar-style': 'default',
    'apple-mobile-web-app-title': 'Wellness',
    'application-name': 'Wellness',
    'msapplication-TileImage': '/favicon.ico',
    'msapplication-config': '/browserconfig.xml',
  },
  icons: {
    icon: [
      { url: '/favicon.ico', sizes: 'any' },
      { url: '/icon.svg', type: 'image/svg+xml' },
    ],
    apple: '/apple-touch-icon.png',
  },
  manifest: '/manifest.json',
};

export default function RootLayout({
  children,
}: Readonly<{
  children: React.ReactNode;
}>) {
  return (
    <html lang="en">
      <body className={`${geistSans.variable} ${geistMono.variable} font-sans antialiased`}>
        <ThemeProvider defaultTheme="dark" storageKey="wellness-theme">
<AOSProvider>
  <StructuredData />
  <SiteHeader />
  {children}
  <SiteFooter />
  <Toaster />
  <Analytics />
</AOSProvider>
        </ThemeProvider>
      </body>
    </html>
  );
}
