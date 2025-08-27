// See the Tailwind configuration guide for advanced usage
// https://tailwindcss.com/docs/configuration

const plugin = require('tailwindcss/plugin')
const colors = require('tailwindcss/colors')

module.exports = {
  darkMode: 'class',
  content: [
    "./js/**/*.js",
    "../lib/starweave_web.ex",
    "../lib/starweave_web/**/*.*ex"
  ],
  theme: {
    extend: {
      colors: {
        // Brand colors
        'pastel-purple': {
          DEFAULT: '#b39ddb',
          50: '#f5f2ff',
          100: '#ede7fe',
          200: '#d9c7ff',
          300: '#b39ddb',
          400: '#9575cd',
          500: '#7e57c2',
          600: '#673ab7',
          700: '#5e35b1',
          800: '#512da8',
          900: '#4527a0',
        },
        'purple-highlight': {
          DEFAULT: '#9575cd',
          50: '#f8f5ff',
          100: '#f0e9ff',
          200: '#d9c7ff',
          300: '#b39ddb',
          400: '#9575cd',
          500: '#7e57c2',
          600: '#673ab7',
          700: '#5e35b1',
          800: '#512da8',
          900: '#4527a0',
        },
        
        // Material Design Colors
        'surface': {
          DEFAULT: '#1e293b',
          50: '#f8fafc',
          100: '#f1f5f9',
          200: '#e2e8f0',
          300: '#cbd5e1',
          400: '#94a3b8',
          500: '#64748b',
          600: '#475569',
          700: '#334155',
          800: '#1e293b',
          900: '#0f172a',
          950: '#020617',
        },
        
        // Text colors
        'text': {
          'primary': '#f8fafc',
          'secondary': '#94a3b8',
          'disabled': '#64748b',
          'hint': '#94a3b8',
        },
        
        // Background colors
        'background': {
          'default': '#0f172a',
          'paper': '#1e293b',
        },
        
        // Status colors
        'success': colors.emerald,
        'warning': colors.amber,
        'error': colors.rose,
        'info': colors.sky,
      },
      
      // Typography
      fontFamily: {
        sans: ['Inter', 'ui-sans-serif', 'system-ui', '-apple-system', 'BlinkMacSystemFont', 'Segoe UI', 'Roboto', 'Helvetica Neue', 'Arial', 'sans-serif'],
        mono: ['Fira Code', 'ui-monospace', 'SFMono-Regular', 'Menlo', 'Monaco', 'Consolas', 'Liberation Mono', 'Courier New', 'monospace'],
      },
      
      // Shadows
      boxShadow: {
        'xs': '0 1px 2px 0 rgba(0, 0, 0, 0.05)',
        'sm': '0 1px 3px 0 rgba(0, 0, 0, 0.1), 0 1px 2px 0 rgba(0, 0, 0, 0.06)',
        'DEFAULT': '0 4px 6px -1px rgba(0, 0, 0, 0.1), 0 2px 4px -1px rgba(0, 0, 0, 0.06)',
        'md': '0 4px 6px -1px rgba(0, 0, 0, 0.1), 0 2px 4px -1px rgba(0, 0, 0, 0.06)',
        'lg': '0 10px 15px -3px rgba(0, 0, 0, 0.1), 0 4px 6px -2px rgba(0, 0, 0, 0.05)',
        'xl': '0 20px 25px -5px rgba(0, 0, 0, 0.1), 0 10px 10px -5px rgba(0, 0, 0, 0.04)',
        '2xl': '0 25px 50px -12px rgba(0, 0, 0, 0.25)',
        'inner': 'inset 0 2px 4px 0 rgba(0, 0, 0, 0.06)',
        'none': 'none',
        'elevation-1': '0 2px 1px -1px rgba(0,0,0,0.2), 0 1px 1px 0 rgba(0,0,0,0.14), 0 1px 3px 0 rgba(0,0,0,0.12)',
        'elevation-2': '0 3px 1px -2px rgba(0,0,0,0.2), 0 2px 2px 0 rgba(0,0,0,0.14), 0 1px 5px 0 rgba(0,0,0,0.12)',
        'elevation-3': '0 3px 3px -2px rgba(0,0,0,0.2), 0 3px 4px 0 rgba(0,0,0,0.14), 0 1px 8px 0 rgba(0,0,0,0.12)',
        'elevation-4': '0 2px 4px -1px rgba(0,0,0,0.2), 0 4px 5px 0 rgba(0,0,0,0.14), 0 1px 10px 0 rgba(0,0,0,0.12)',
        'elevation-6': '0 3px 5px -1px rgba(0,0,0,0.2), 0 6px 10px 0 rgba(0,0,0,0.14), 0 1px 18px 0 rgba(0,0,0,0.12)',
      },
      
      // Animations
      animation: {
        'pulse-slow': 'pulse 3s cubic-bezier(0.4, 0, 0.6, 1) infinite',
        'float': 'float 6s ease-in-out infinite',
        'bounce': 'bounce 1.5s infinite',
        'fade-in': 'fadeIn 0.3s ease-out',
        'slide-up': 'slideUp 0.3s ease-out',
      },
      
      // Keyframes
      keyframes: {
        float: {
          '0%, 100%': { transform: 'translateY(0)' },
          '50%': { transform: 'translateY(-6px)' },
        },
        bounce: {
          '0%, 100%': { transform: 'translateY(-25%)', animationTimingFunction: 'cubic-bezier(0.8, 0, 1, 1)' },
          '50%': { transform: 'translateY(0)', animationTimingFunction: 'cubic-bezier(0, 0, 0.2, 1)' },
        },
        fadeIn: {
          '0%': { opacity: 0, transform: 'translateY(10px)' },
          '100%': { opacity: 1, transform: 'translateY(0)' },
        },
        slideUp: {
          '0%': { transform: 'translateY(20px)', opacity: 0 },
          '100%': { transform: 'translateY(0)', opacity: 1 },
        },
      },
      
      // Border radius
      borderRadius: {
        'none': '0px',
        'sm': '0.25rem',
        'DEFAULT': '0.375rem',
        'md': '0.5rem',
        'lg': '0.75rem',
        'xl': '1rem',
        '2xl': '1.5rem',
        '3xl': '2rem',
        'full': '9999px',
      },
      
      // Spacing
      spacing: {
        '18': '4.5rem',
        '22': '5.5rem',
        '26': '6.5rem',
        '30': '7.5rem',
        '34': '8.5rem',
        '38': '9.5rem',
        '42': '10.5rem',
        '46': '11.5rem',
        '50': '12.5rem',
      },
    },
  },
  plugins: [
    require('@tailwindcss/typography'),
    require('@tailwindcss/forms')({
      strategy: 'class',
    }),
    require('@tailwindcss/line-clamp'),
    require('@tailwindcss/aspect-ratio'),
    
    // Custom plugin for Material Design components
    plugin(function({ addComponents, theme }) {
      addComponents({
        // Container
        '.container': {
          width: '100%',
          marginLeft: 'auto',
          marginRight: 'auto',
          paddingLeft: theme('spacing.4'),
          paddingRight: theme('spacing.4'),
          '@screen sm': {
            maxWidth: theme('screens.sm'),
          },
          '@screen md': {
            maxWidth: theme('screens.md'),
          },
          '@screen lg': {
            maxWidth: theme('screens.lg'),
          },
          '@screen xl': {
            maxWidth: theme('screens.xl'),
          },
          '@screen 2xl': {
            maxWidth: theme('screens.2xl'),
          },
        },
        
        // Buttons
        '.btn': {
          display: 'inline-flex',
          alignItems: 'center',
          justifyContent: 'center',
          borderRadius: theme('borderRadius.DEFAULT'),
          padding: '0.625rem 1.25rem',
          fontSize: '0.875rem',
          fontWeight: '500',
          lineHeight: '1.25',
          transitionProperty: 'all',
          transitionTimingFunction: 'cubic-bezier(0.4, 0, 0.2, 1)',
          transitionDuration: '150ms',
          '&:focus': {
            outline: '2px solid transparent',
            outlineOffset: '2px',
            '--tw-ring-offset-shadow': 'var(--tw-ring-inset) 0 0 0 var(--tw-ring-offset-width) var(--tw-ring-offset-color)',
            '--tw-ring-shadow': 'var(--tw-ring-inset) 0 0 0 calc(2px + var(--tw-ring-offset-width)) var(--tw-ring-color)',
            boxShadow: 'var(--tw-ring-offset-shadow), var(--tw-ring-shadow), var(--tw-shadow, 0 0 #0000)',
            '--tw-ring-opacity': '1',
            '--tw-ring-color': 'rgb(149 117 205 / var(--tw-ring-opacity))',
            '--tw-ring-opacity': '0.5',
          },
          '&:disabled': {
            opacity: '0.6',
            pointerEvents: 'none',
            cursor: 'not-allowed',
          },
        },
        
        '.btn-primary': {
          backgroundColor: theme('colors.purple-highlight.DEFAULT'),
          color: theme('colors.white'),
          boxShadow: theme('boxShadow.sm'),
          '&:hover': {
            backgroundColor: theme('colors.purple-highlight.600'),
            boxShadow: theme('boxShadow.DEFAULT'),
          },
          '&:active': {
            backgroundColor: theme('colors.purple-highlight.700'),
          },
        },
        
        '.btn-secondary': {
          backgroundColor: theme('colors.surface.700'),
          color: theme('colors.text.primary'),
          border: `1px solid ${theme('colors.surface.600')}`,
          '&:hover': {
            backgroundColor: theme('colors.surface.600'),
            borderColor: theme('colors.surface.500'),
          },
        },
        
        '.btn-ghost': {
          color: theme('colors.text.secondary'),
          '&:hover': {
            backgroundColor: theme('colors.surface.700'),
            color: theme('colors.text.primary'),
          },
        },
        
        // Inputs
        '.input': {
          width: '100%',
          borderRadius: theme('borderRadius.DEFAULT'),
          border: `1px solid ${theme('colors.surface.600')}`,
          backgroundColor: theme('colors.surface.700'),
          padding: '0.625rem 1rem',
          borderColor: theme('colors.light-grey'),
          backgroundColor: theme('colors.dark-grey'),
          color: theme('colors.text.primary'),
          fontSize: '0.875rem',
          lineHeight: '1.25rem',
          transitionProperty: 'background-color, border-color, color, fill, stroke, opacity, box-shadow, transform',
          transitionTimingFunction: 'cubic-bezier(0.4, 0, 0.2, 1)',
          transitionDuration: '150ms',
          '&:focus': {
            outline: 'none',
            ring: '2px',
            ringOffset: '2px',
            ringColor: 'rgba(179, 157, 219, 0.5)',
            borderColor: theme('colors.purple-highlight'),
          },
          '&::placeholder': {
            color: theme('colors.text.disabled'),
          },
        },
        
        // Material cards
        '.card': {
          backgroundColor: theme('colors.dark-grey'),
          borderRadius: '0.5rem',
          boxShadow: theme('boxShadow.DEFAULT'),
          overflow: 'hidden',
        },
        
        // Glow effect
        '.glow': {
          boxShadow: '0 0 15px rgba(179, 157, 219, 0.3)',
          transition: 'box-shadow 0.3s ease',
        },
      };
      
      addComponents(components);
    },
  ],
}
