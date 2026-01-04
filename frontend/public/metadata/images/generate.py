#!/usr/bin/env python3
"""Generate NFT images with AnIT color scheme variations."""

import random
import math

# AnIT Color Palette
COLORS = {
    'orange_primary': '#F7931E',
    'orange_dark': '#FF6B00',
    'orange_light': '#FFB347',
    'gray_dark': '#3d3d3d',
    'gray_medium': '#4a4a4a',
    'gray_light': '#5a5a5a',
    'white': '#FFFFFF',
    'silver': '#C0C0C0',
}

def generate_triangles(seed, count=5):
    """Generate random decorative triangles."""
    random.seed(seed)
    triangles = []
    for _ in range(count):
        x = random.randint(20, 450)
        y = random.randint(20, 150)
        size = random.randint(30, 60)
        opacity = random.uniform(0.4, 0.8)
        rotation = random.randint(0, 360)
        triangles.append(f'''    <polygon points="{x},{y} {x+size},{y+size} {x-size//2},{y+size}"
             fill="url(#orange1)" opacity="{opacity:.2f}"
             transform="rotate({rotation} {x} {y+size//2})"/>''')
    return '\n'.join(triangles)

def generate_bottom_triangles(seed):
    """Generate bottom accent triangles."""
    random.seed(seed + 1000)
    triangles = []
    for i in range(3):
        x = random.randint(350, 480)
        y = random.randint(380, 420)
        size = random.randint(40, 70)
        opacity = random.uniform(0.5, 0.9)
        triangles.append(f'''    <polygon points="{x},{y} {x+size//2},{y+size} {x-size//2},{y+size}"
             fill="url(#orange1)" opacity="{opacity:.2f}"/>''')
    return '\n'.join(triangles)

def generate_swoosh_variation(seed):
    """Generate swoosh path variation."""
    random.seed(seed + 2000)
    y_base = random.randint(330, 370)
    curve = random.randint(30, 60)
    return f'''    <path d="M 50,{y_base} Q 150,{y_base-curve} 250,{y_base} T 450,{y_base}"
          fill="none" stroke="#FFFFFF" stroke-width="{random.randint(6,10)}" opacity="0.9"/>
    <path d="M 50,{y_base+20} Q 150,{y_base+20-curve} 250,{y_base+20} T 450,{y_base+20}"
          fill="none" stroke="url(#orange1)" stroke-width="{random.randint(3,6)}" opacity="0.7"/>'''

def generate_center_symbol(seed, token_id):
    """Generate center symbol variation."""
    random.seed(seed + 3000)
    symbols = ['N', 'hexagon', 'diamond', 'star']
    symbol_type = symbols[seed % len(symbols)]

    if symbol_type == 'N':
        return '''    <!-- Main Nexus Symbol - Geometric N -->
    <g transform="translate(150, 120)" filter="url(#glow)">
      <polygon points="100,0 200,50 200,150 100,200 0,150 0,50"
               fill="none" stroke="#F7931E" stroke-width="4"/>
      <path d="M 60,160 L 60,40 L 80,40 L 140,130 L 140,40 L 160,40 L 160,160 L 140,160 L 80,70 L 80,160 Z"
            fill="#FFFFFF"/>
    </g>'''
    elif symbol_type == 'hexagon':
        return '''    <!-- Main Nexus Symbol - Hexagon -->
    <g transform="translate(150, 120)" filter="url(#glow)">
      <polygon points="100,0 200,50 200,150 100,200 0,150 0,50"
               fill="none" stroke="#F7931E" stroke-width="6"/>
      <polygon points="100,30 170,65 170,135 100,170 30,135 30,65"
               fill="url(#orange1)" opacity="0.3"/>
      <text x="100" y="115" font-family="Arial" font-size="60" font-weight="bold"
            fill="#FFFFFF" text-anchor="middle">N</text>
    </g>'''
    elif symbol_type == 'diamond':
        return '''    <!-- Main Nexus Symbol - Diamond -->
    <g transform="translate(150, 100)" filter="url(#glow)">
      <polygon points="100,0 200,100 100,200 0,100"
               fill="none" stroke="#F7931E" stroke-width="5"/>
      <polygon points="100,30 170,100 100,170 30,100"
               fill="url(#orange1)" opacity="0.4"/>
      <circle cx="100" cy="100" r="40" fill="#FFFFFF"/>
      <text x="100" y="115" font-family="Arial" font-size="50" font-weight="bold"
            fill="#4a4a4a" text-anchor="middle">N</text>
    </g>'''
    else:  # star
        return '''    <!-- Main Nexus Symbol - Star -->
    <g transform="translate(150, 100)" filter="url(#glow)">
      <polygon points="100,0 120,70 200,70 140,115 160,190 100,145 40,190 60,115 0,70 80,70"
               fill="none" stroke="#F7931E" stroke-width="4"/>
      <polygon points="100,30 115,75 165,75 125,105 140,155 100,125 60,155 75,105 35,75 85,75"
               fill="url(#orange1)" opacity="0.5"/>
      <circle cx="100" cy="100" r="30" fill="#FFFFFF"/>
    </g>'''

def generate_svg(token_id):
    """Generate complete SVG for a token."""
    seed = token_id

    svg = f'''<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 500 500">
  <defs>
    <linearGradient id="bg1" x1="0%" y1="0%" x2="100%" y2="100%">
      <stop offset="0%" style="stop-color:#3d3d3d"/>
      <stop offset="100%" style="stop-color:#4a4a4a"/>
    </linearGradient>
    <linearGradient id="orange1" x1="0%" y1="0%" x2="100%" y2="100%">
      <stop offset="0%" style="stop-color:#F7931E"/>
      <stop offset="100%" style="stop-color:#FF6B00"/>
    </linearGradient>
    <filter id="glow">
      <feGaussianBlur stdDeviation="3" result="coloredBlur"/>
      <feMerge>
        <feMergeNode in="coloredBlur"/>
        <feMergeNode in="SourceGraphic"/>
      </feMerge>
    </filter>
  </defs>

  <!-- Background -->
  <rect width="500" height="500" fill="url(#bg1)"/>

  <!-- Decorative triangles (AnIT inspired) -->
{generate_triangles(seed)}

{generate_center_symbol(seed, token_id)}

  <!-- Swoosh element (AnIT inspired) -->
{generate_swoosh_variation(seed)}

  <!-- Bottom accent triangles -->
{generate_bottom_triangles(seed)}

  <!-- Token ID badge -->
  <rect x="380" y="20" width="100" height="40" rx="20" fill="url(#orange1)"/>
  <text x="430" y="48" font-family="Arial, sans-serif" font-size="20" font-weight="bold" fill="#FFFFFF" text-anchor="middle">#{token_id}</text>

  <!-- Nexus text -->
  <text x="250" y="460" font-family="Arial, sans-serif" font-size="36" font-weight="bold" fill="#FFFFFF" text-anchor="middle">NEXUS</text>
  <text x="250" y="485" font-family="Arial, sans-serif" font-size="14" fill="#F7931E" text-anchor="middle">GENESIS COLLECTION</text>
</svg>'''
    return svg

def main():
    # Generate first 20 token images
    for token_id in range(1, 21):
        svg_content = generate_svg(token_id)
        with open(f'{token_id}.svg', 'w') as f:
            f.write(svg_content)
        print(f'Generated {token_id}.svg')

if __name__ == '__main__':
    main()
