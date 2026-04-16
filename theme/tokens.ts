export type ThemeName = 'classic' | 'eras' | 'romfantasy';

export interface ThemeTokens {
  bg: string;
  bgSecondary: string;
  primary: string;
  primaryFaded: string;
  accent: string;
  text: string;
  textMuted: string;
  border: string;
  card: string;
  fontDisplay: string;
  fontBody: string;
  radius: number;
  radiusLg: number;
}

export const themes: Record<ThemeName, ThemeTokens> = {
  classic: {
    bg: '#FAF7F0',
    bgSecondary: '#F2EDE4',
    primary: '#8B4513',
    primaryFaded: '#8B451322',
    accent: '#D4A853',
    text: '#2C1810',
    textMuted: '#8A7560',
    border: '#E8DFD0',
    card: '#FFFFFF',
    fontDisplay: 'PlayfairDisplay_700Bold',
    fontBody: 'SourceSerif4_400Regular',
    radius: 8,
    radiusLg: 16,
  },
  eras: {
    bg: '#1A0533',
    bgSecondary: '#2D0A52',
    primary: '#C77DFF',
    primaryFaded: '#C77DFF22',
    accent: '#FFD6E7',
    text: '#F5E6FF',
    textMuted: '#A890C0',
    border: '#3D1566',
    card: '#2D0A52',
    fontDisplay: 'Outfit_700Bold',
    fontBody: 'DMSans_400Regular',
    radius: 24,
    radiusLg: 32,
  },
  romfantasy: {
    bg: '#0D0608',
    bgSecondary: '#1A0A0E',
    primary: '#8B0000',
    primaryFaded: '#8B000022',
    accent: '#CFB53B',
    text: '#F0E6D3',
    textMuted: '#9E8B7A',
    border: '#2A1218',
    card: '#1A0A0E',
    fontDisplay: 'CormorantGaramond_700Bold',
    fontBody: 'Lora_400Regular',
    radius: 4,
    radiusLg: 8,
  },
};
