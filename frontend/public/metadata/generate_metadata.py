#!/usr/bin/env python3
"""Generate NFT metadata JSON files."""

import json
import random

# Trait options
BACKGROUNDS = ['Charcoal', 'Slate', 'Obsidian', 'Graphite']
SYMBOLS = ['Hexagon', 'Diamond', 'Star', 'Classic N']
ACCENTS = ['Sunrise Orange', 'Ember', 'Tangerine', 'Flame']
RARITIES = ['Common', 'Uncommon', 'Rare', 'Epic', 'Legendary']
RARITY_WEIGHTS = [50, 30, 15, 4, 1]

def get_rarity(token_id):
    """Determine rarity based on token ID."""
    random.seed(token_id)
    return random.choices(RARITIES, weights=RARITY_WEIGHTS)[0]

def get_traits(token_id):
    """Generate traits for a token."""
    random.seed(token_id)
    return {
        'Background': random.choice(BACKGROUNDS),
        'Symbol': SYMBOLS[token_id % len(SYMBOLS)],
        'Accent': random.choice(ACCENTS),
        'Rarity': get_rarity(token_id),
        'Generation': 'Genesis',
        'Edition': token_id,
    }

def generate_metadata(token_id, base_url):
    """Generate metadata for a token."""
    traits = get_traits(token_id)

    metadata = {
        'name': f'Nexus Genesis #{token_id}',
        'description': f'Nexus Genesis NFT #{token_id} - A unique digital collectible from the Nexus Protocol Genesis Collection. Holders receive 10% staking boost, 1.5x governance voting power, and exclusive access to protocol features.',
        'image': f'{base_url}/metadata/images/{token_id}.svg',
        'external_url': f'https://nexusprotocol.io/nft/{token_id}',
        'attributes': [
            {'trait_type': 'Background', 'value': traits['Background']},
            {'trait_type': 'Symbol', 'value': traits['Symbol']},
            {'trait_type': 'Accent', 'value': traits['Accent']},
            {'trait_type': 'Rarity', 'value': traits['Rarity']},
            {'trait_type': 'Generation', 'value': traits['Generation']},
            {'display_type': 'number', 'trait_type': 'Edition', 'value': traits['Edition']},
        ],
    }
    return metadata

def main():
    # Base URL for local development
    base_url = 'http://localhost:3000'

    # Generate first 20 token metadata files
    for token_id in range(1, 21):
        metadata = generate_metadata(token_id, base_url)
        with open(f'{token_id}.json', 'w') as f:
            json.dump(metadata, f, indent=2)
        print(f'Generated {token_id}.json - {metadata["attributes"][3]["value"]} {metadata["attributes"][1]["value"]}')

if __name__ == '__main__':
    main()
