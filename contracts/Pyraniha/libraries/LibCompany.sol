pragma solidity ^0.8.8;

import {LibAppStorage, AppStorage, ItemType, Aavegotchi, EQUIPPED_WEARABLE_SLOTS} from "./LibAppStorage.sol";
import {LibERC1155} from "../../shared/libraries/LibERC1155.sol";

library LibCompany {

  struct CompanyCollateralTypeIO {
    address collateralType;
    AavegotchiCollateralTypeInfo collateralTypeInfo;
}

struct CompanyInfo {
    uint256 tokenId;
    string name;
    string description;
    string sector;
    string activity;
    address owner;
    address founder;
    address escrow;
    address collateral;
    int16[NUMERIC_TRAITS_NUM] numericTraits;
    int16[NUMERIC_TRAITS_NUM] modifiedNumericTraits;
    uint16[EQUIPPED_WEARABLE_SLOTS] equippedWearables;
    uint256 status;
    uint256 maxRecruit; // determined by level
    uint256 maxActivityType; // Differents works determined by owner that recruits can accomplish 
    uint256 experience; //How much XP this Aavegotchi has accrued. Begins at 0.
    uint256 toNextLevel;
    uint256 level; //the current aavegotchi level
    uint256 minimumStake;
    uint256 stakedAmount;
    uint256 usedSkillPoints; //number of skill points used
    uint256 adhesion; //The kinship value of this Aavegotchi. Default is 50.
    uint256 lastInteracted;

    uint256 cycleId;
    uint256 baseRarityScore;
    uint256 modifiedRarityScore;
    bool locked;
    ItemTypeIO[] items;
}

    function getCompany(uint256 _tokenId) internal view returns (CompanyInfo memory companyInfo_) {
        AppStorage storage s = LibAppStorage.diamondStorage();
        companyInfo_.tokenId = _tokenId;
        companyInfo_.owner = s.companies[_tokenId].owner;
        companyInfo_.founder = s.companies[_tokenId].founder;
        companyInfo_.status = s.companies[_tokenId].status;
        companyInfo_.cycleId = s.companies[_tokenId].cycleId;
        if (companyInfo_.status == STATUS_AAVEGOTCHI) {
            companyInfo_.name = s.companies[_tokenId].name;
            companyInfo_.equippedWearables = s.companies[_tokenId].equippedWearables;
            companyInfo_.collateral = s.companies[_tokenId].collateralType;
            companyInfo_.escrow = s.companies[_tokenId].escrow;
            companyInfo_.stakedAmount = IERC20(companyInfo_.collateral).balanceOf(companyInfo_.escrow);
            companyInfo_.minimumStake = s.companies[_tokenId].minimumStake;
            companyInfo_.adhesion = adhesion(_tokenId);
            companyInfo_.lastInteracted = s.companies[_tokenId].lastInteracted;
            companyInfo_.experience = s.companies[_tokenId].experience;
            companyInfo_.toNextLevel = xpUntilNextLevel(s.companies[_tokenId].experience);
            companyInfo_.level = companyLevel(s.companies[_tokenId].experience);
            companyInfo_.usedSkillPoints = s.companies[_tokenId].usedSkillPoints;
            companyInfo_.numericTraits = s.companies[_tokenId].numericTraits;
            companyInfo_.baseRarityScore = baseRarityScore(companyInfo_.numericTraits);
            (companyInfo_.modifiedNumericTraits, companyInfo_.modifiedRarityScore) = modifiedTraitsAndRarityScore(_tokenId);
            companyInfo_.locked = s.companies[_tokenId].locked;
            companyInfo_.items = LibItems.itemBalancesOfTokenWithTypes(address(this), _tokenId);
        }
    }

    function adhesion(uint256 _tokenId) internal view returns (uint256 score_) {
        AppStorage storage s = LibAppStorage.diamondStorage();
        Company storage company = s.companys[_tokenId];
        uint256 lastInteracted = company.lastInteracted;
        uint256 interactionCount = company.interactionCount;
        uint256 interval = block.timestamp - lastInteracted;

        uint256 daysSinceInteraction = interval / 24 hours;

        if (interactionCount > daysSinceInteraction) {
            score_ = interactionCount - daysSinceInteraction;
        }
    }

    function xpUntilNextLevel(uint256 _experience) internal pure returns (uint256 requiredXp_) {
        uint256 currentLevel = companyLevel(_experience);
        requiredXp_ = ((currentLevel**2) * 50) - _experience;
    }

    function companyLevel(uint256 _experience) internal pure returns (uint256 level_) {
        if (_experience > 490050) {
            return 99;
        }

        level_ = (sqrt(2 * _experience) / 10);
        return level_ + 1;
    }


    //Only valid for claimed Aavegotchis
    function modifiedTraitsAndRarityScore(uint256 _tokenId)
        internal
        view
        returns (int16[NUMERIC_TRAITS_NUM] memory numericTraits_, uint256 rarityScore_)
    {
        Company storage s = LibAppStorage.diamondStorage();
        require(s.companies[_tokenId].status == STATUS_AAVEGOTCHI, "AavegotchiFacet: Must be claimed");
        Company storage company = s.companies[_tokenId];
        numericTraits_ = getNumericTraits(_tokenId);
        uint256 wearableBonus;
        for (uint256 slot; slot < EQUIPPED_WEARABLE_SLOTS; slot++) {
            uint256 wearableId = company.equippedWearables[slot];
            if (wearableId == 0) {
                continue;
            }
            ItemType storage itemType = s.itemTypes[wearableId];
            //Add on trait modifiers
            for (uint256 j; j < NUMERIC_TRAITS_NUM; j++) {
                numericTraits_[j] += itemType.traitModifiers[j];
            }
            wearableBonus += itemType.rarityScoreModifier;
        }
        uint256 baseRarity = baseRarityScore(numericTraits_);
        rarityScore_ = baseRarity + wearableBonus;
    }

    function getNumericTraits(uint256 _tokenId) internal view returns (int16[NUMERIC_TRAITS_NUM] memory numericTraits_) {
        AppStorage storage s = LibAppStorage.diamondStorage();
        //Check if trait boosts from consumables are still valid
        int256 boostDecay = int256((block.timestamp - s.companies[_tokenId].lastTemporaryBoost) / 24 hours);
        for (uint256 i; i < NUMERIC_TRAITS_NUM; i++) {
            int256 number = s.companies[_tokenId].numericTraits[i];
            int256 boost = s.companies[_tokenId].temporaryTraitBoosts[i];

            if (boost > 0 && boost > boostDecay) {
                number += boost - boostDecay;
            } else if ((boost * -1) > boostDecay) {
                number += boost + boostDecay;
            }
            numericTraits_[i] = int16(number);
        }
    }

}