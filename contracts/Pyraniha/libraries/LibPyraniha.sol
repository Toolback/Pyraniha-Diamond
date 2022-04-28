pragma solidity ^0.8.8;

import {AppStorage, LibAppStorage, Pyraniha, PyranihaCollateralTypeInfo, ItemType, NUMERIC_TRAITS_NUM, EQUIPPED_WEARABLE_SLOTS, EGG_PYRANIHAS_NUM} from "./LibAppStorage.sol";
import {LibItems, ItemTypeIO} from "../libraries/LibItems.sol";

import {IERC20} from "../../shared/interfaces/IERC20.sol";
import {LibERC20} from "../../shared/libraries/LibERC20.sol";
import {LibMeta} from "../../shared/libraries/LibMeta.sol";
import {IERC721} from "../../shared/interfaces/IERC721.sol";
import {LibERC721} from "../../shared/libraries/LibERC721.sol";

struct PyranihaCollateralTypeIO {
  address collateralType;
  PyranihaCollateralTypeInfo collateralTypeInfo;
}

struct PyranihaInfo {
    uint256 tokenId;
    string name;
    address owner;
    uint256 randomNumber; // ?? do i still have to keep it ? 
    uint256 status;
    int16[NUMERIC_TRAITS_NUM] numericTraits;
    int16[NUMERIC_TRAITS_NUM] modifiedNumericTraits;
    uint16[EQUIPPED_WEARABLE_SLOTS] equippedWearables;
    address collateral;
    address escrow;
    uint256 stakedAmount; //
    uint256 minimumStake; //
    uint256 kinship; //The kinship value of this Aavegotchi. Default is 50.
    uint256 lastInteracted; //
    uint256 experience; //How much XP this Aavegotchi has accrued. Begins at 0.
    uint256 toNextLevel; //
    uint256 usedSkillPoints; //number of skill points used
    uint256 level; //the current aavegotchi level
    uint256 cycleId;
    uint256 baseRarityScore;
    uint256 modifiedRarityScore;
    bool locked;
    ItemTypeIO[] items;
    
}

struct EggPyranihaTraitsIO {
  uint256 randomNumber;
    int16[NUMERIC_TRAITS_NUM] numericTraits;
    address collateralType;
    uint256 minimumStake;
}

struct InternalEggPyranihaTraitsIO {
  uint256 randomNumber;
    int16[NUMERIC_TRAITS_NUM] numericTraits;
    address collateralType;
    uint256 minimumStake;
}

library LibPyraniha {
  uint8 constant STATUS_EGG = 0;
  uint8 constant STATUS_VRF_PENDING = 1;
  uint8 constant STATUS_OPEN_EGG = 2;
  uint8 constant STATUS_PYRANIHA = 3;

  event PyranihaInteract(uint256 indexed _tokenId, uint256 kinship);

    function toNumericTraits(
        uint256 _randomNumber,
        int16[NUMERIC_TRAITS_NUM] memory _modifiers,
        uint256 _hauntId
    ) internal pure returns (int16[NUMERIC_TRAITS_NUM] memory numericTraits_) {
        if (_hauntId == 1) {
            for (uint256 i; i < NUMERIC_TRAITS_NUM; i++) {
                uint256 value = uint8(uint256(_randomNumber >> (i * 8)));
                if (value > 99) {
                    value /= 2;
                    if (value > 99) {
                        value = uint256(keccak256(abi.encodePacked(_randomNumber, i))) % 100;
                    }
                }
                numericTraits_[i] = int16(int256(value)) + _modifiers[i];
            }
        } else {
            for (uint256 i; i < NUMERIC_TRAITS_NUM; i++) {
                uint256 value = uint8(uint256(_randomNumber >> (i * 8)));
                if (value > 99) {
                    value = value - 100;
                    if (value > 99) {
                        value = uint256(keccak256(abi.encodePacked(_randomNumber, i))) % 100;
                    }
                }
                numericTraits_[i] = int16(int256(value)) + _modifiers[i];
            }
        }
    }

    function rarityMultiplier(int16[NUMERIC_TRAITS_NUM] memory _numericTraits) internal pure returns (uint256 multiplier) {
        uint256 rarityScore = LibPyraniha.baseRarityScore(_numericTraits);
        if (rarityScore < 300) return 10;
        else if (rarityScore >= 300 && rarityScore < 450) return 10;
        else if (rarityScore >= 450 && rarityScore <= 525) return 25;
        else if (rarityScore >= 526 && rarityScore <= 580) return 100;
        else if (rarityScore >= 581) return 1000;
    }

        function singleEggPyranihaTraits(uint256 _randomNumber, uint256 _option)
        internal
        view
        returns (InternalEggPyranihaTraitsIO memory singleEggPyranihaTraits_)
    {
        AppStorage storage s = LibAppStorage.diamondStorage();
        uint256 randomNumberN = uint256(keccak256(abi.encodePacked(_randomNumber, _option)));
        singleEggPyranihaTraits_.randomNumber = randomNumberN;
        address collateralType = s.collateralTypes[randomNumberN % s.collateralTypes.length];
        singleEggPyranihaTraits_.numericTraits = toNumericTraits(randomNumberN, s.collateralTypeInfo[collateralType].modifiers);
        singleEggPyranihaTraits_.collateralType = collateralType;

        PyranihaCollateralTypeInfo memory collateralInfo = s.collateralTypeInfo[collateralType];
        uint256 conversionRate = collateralInfo.conversionRate;

        //Get rarity multiplier
        uint256 multiplier = rarityMultiplier(singleEggPyranihaTraits_.numericTraits);

        //First we get the base price of our collateral in terms of DAI
        uint256 collateralDAIPrice = ((10**IERC20(collateralType).decimals()) / conversionRate);

        //Then multiply by the rarity multiplier
        singleEggPyranihaTraits_.minimumStake = collateralDAIPrice * multiplier;
    }

    // TODO :// Change Traits for Caract ? 

    function eggPyranihaTraits(uint256 _tokenId)
        internal
        view
        returns (EggPyranihaTraitsIO[EGG_PYRANIHAS_NUM] memory eggPyranihaTraits_)
    {
        AppStorage storage s = LibAppStorage.diamondStorage();
        require(s.pyranihas[_tokenId].status == LibPyraniha.STATUS_OPEN_PORTAL, "PyranihaFacet: Portal not open");

        uint256 randomNumber = s.tokenIdToRandomNumber[_tokenId];

        for (uint256 i; i < eggPyranihaTraits_.length; i++) {
            InternalEggPyranihaTraitsIO memory single = singleEggPyranihaTraits(randomNumber, i);
            eggPyranihaTraits_[i].randomNumber = single.randomNumber;
            eggPyranihaTraits_[i].collateralType = single.collateralType;
            eggPyranihaTraits_[i].minimumStake = single.minimumStake;
            eggPyranihaTraits_[i].numericTraits = single.numericTraits;
        }
    }

    function getPyraniha(uint256 _tokenId) internal view returns (PyranihaInfo memory pyranihaInfo_) {
        AppStorage storage s = LibAppStorage.diamondStorage();
        pyranihaInfo_.tokenId = _tokenId;
        pyranihaInfo_.owner = s.pyranihas[_tokenId].owner;
        pyranihaInfo_.randomNumber = s.pyranihas[_tokenId].randomNumber;
        pyranihaInfo_.status = s.pyranihas[_tokenId].status;
        pyranihaInfo_.hauntId = s.pyranihas[_tokenId].hauntId;
        if (pyranihaInfo_.status == STATUS_PYRANIHA) {
            pyranihaInfo_.name = s.pyranihas[_tokenId].name;
            pyranihaInfo_.equippedWearables = s.pyranihas[_tokenId].equippedWearables;
            pyranihaInfo_.collateral = s.pyranihas[_tokenId].collateralType;
            pyranihaInfo_.escrow = s.pyranihas[_tokenId].escrow;
            pyranihaInfo_.stakedAmount = IERC20(pyranihaInfo_.collateral).balanceOf(pyranihaInfo_.escrow);
            pyranihaInfo_.minimumStake = s.pyranihas[_tokenId].minimumStake;
            pyranihaInfo_.kinship = kinship(_tokenId);
            pyranihaInfo_.lastInteracted = s.pyranihas[_tokenId].lastInteracted;
            pyranihaInfo_.experience = s.pyranihas[_tokenId].experience;
            pyranihaInfo_.toNextLevel = xpUntilNextLevel(s.pyranihas[_tokenId].experience);
            pyranihaInfo_.level = pyranihaLevel(s.pyranihas[_tokenId].experience);
            pyranihaInfo_.usedSkillPoints = s.pyranihas[_tokenId].usedSkillPoints;
            pyranihaInfo_.numericTraits = s.pyranihas[_tokenId].numericTraits;
            pyranihaInfo_.baseRarityScore = baseRarityScore(pyranihaInfo_.numericTraits);
            (pyranihaInfo_.modifiedNumericTraits, pyranihaInfo_.modifiedRarityScore) = modifiedTraitsAndRarityScore(_tokenId);
            pyranihaInfo_.locked = s.pyranihas[_tokenId].locked;
            pyranihaInfo_.items = LibItems.itemBalancesOfTokenWithTypes(address(this), _tokenId);
        }
    }

    //Only valid for claimed Aavegotchis
    function modifiedTraitsAndRarityScore(uint256 _tokenId)
        internal
        view
        returns (int16[NUMERIC_TRAITS_NUM] memory numericTraits_, uint256 rarityScore_)
    {
        AppStorage storage s = LibAppStorage.diamondStorage();
        require(s.pyranihas[_tokenId].status == STATUS_AAVEGOTCHI, "AavegotchiFacet: Must be claimed");
        Pyraniha storage pyraniha = s.pyranihas[_tokenId];
        numericTraits_ = getNumericTraits(_tokenId);
        uint256 wearableBonus;
        for (uint256 slot; slot < EQUIPPED_WEARABLE_SLOTS; slot++) {
            uint256 wearableId = pyraniha.equippedWearables[slot];
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
        int256 boostDecay = int256((block.timestamp - s.pyranihas[_tokenId].lastTemporaryBoost) / 24 hours);
        for (uint256 i; i < NUMERIC_TRAITS_NUM; i++) {
            int256 number = s.pyranihas[_tokenId].numericTraits[i];
            int256 boost = s.pyranihas[_tokenId].temporaryTraitBoosts[i];

            if (boost > 0 && boost > boostDecay) {
                number += boost - boostDecay;
            } else if ((boost * -1) > boostDecay) {
                number += boost + boostDecay;
            }
            numericTraits_[i] = int16(number);
        }
    }

    function kinship(uint256 _tokenId) internal view returns (uint256 score_) {
        AppStorage storage s = LibAppStorage.diamondStorage();
        Pyraniha storage pyraniha = s.pyranihas[_tokenId];
        uint256 lastInteracted = pyraniha.lastInteracted;
        uint256 interactionCount = pyraniha.interactionCount;
        uint256 interval = block.timestamp - lastInteracted;

        uint256 daysSinceInteraction = interval / 24 hours;

        if (interactionCount > daysSinceInteraction) {
            score_ = interactionCount - daysSinceInteraction;
        }
    }

    function xpUntilNextLevel(uint256 _experience) internal pure returns (uint256 requiredXp_) {
        uint256 currentLevel = pyranihaLevel(_experience);
        requiredXp_ = ((currentLevel**2) * 50) - _experience;
    }

    function pyranihaLevel(uint256 _experience) internal pure returns (uint256 level_) {
        if (_experience > 490050) {
            return 99;
        }

        level_ = (sqrt(2 * _experience) / 10);
        return level_ + 1;
    }

    function interact(uint256 _tokenId) internal returns (bool) {
        AppStorage storage s = LibAppStorage.diamondStorage();
        uint256 lastInteracted = s.pyranihas[_tokenId].lastInteracted;
        // if interacted less than 12 hours ago
        if (block.timestamp < lastInteracted + 12 hours) {
            return false;
        }

        uint256 interactionCount = s.pyranihas[_tokenId].interactionCount;
        uint256 interval = block.timestamp - lastInteracted;
        uint256 daysSinceInteraction = interval / 1 days;
        uint256 l_kinship;
        if (interactionCount > daysSinceInteraction) {
            l_kinship = interactionCount - daysSinceInteraction;
        }

        uint256 hateBonus;

        if (l_kinship < 40) {
            hateBonus = 2;
        }
        l_kinship += 1 + hateBonus;
        s.pyranihas[_tokenId].interactionCount = l_kinship;

        s.pyranihas[_tokenId].lastInteracted = uint40(block.timestamp);
        emit PyranihaInteract(_tokenId, l_kinship);
        return true;
    }

    //Calculates the base rarity score, including collateral modifier
    function baseRarityScore(int16[NUMERIC_TRAITS_NUM] memory _numericTraits) internal pure returns (uint256 _rarityScore) {
        for (uint256 i; i < NUMERIC_TRAITS_NUM; i++) {
            int256 number = _numericTraits[i];
            if (number >= 50) {
                _rarityScore += uint256(number) + 1;
            } else {
                _rarityScore += uint256(int256(100) - number);
            }
        }
    }

    // Need to ensure there is no overflow of _ghst
    function purchase(address _from, uint256 _ghst) internal {
        AppStorage storage s = LibAppStorage.diamondStorage();
        //33% to burn address
        uint256 burnShare = (_ghst * 33) / 100;

        //17% to Pixelcraft wallet
        uint256 companyShare = (_ghst * 17) / 100;

        //40% to rarity farming rewards
        uint256 rarityFarmShare = (_ghst * 2) / 5;

        //10% to DAO
        uint256 daoShare = (_ghst - burnShare - companyShare - rarityFarmShare);

        // Using 0xFFfFfFffFFfffFFfFFfFFFFFffFFFffffFfFFFfF as burn address.
        // GHST token contract does not allow transferring to address(0) address: https://etherscan.io/address/0x3F382DbD960E3a9bbCeaE22651E88158d2791550#code
        address ghstContract = s.ghstContract;
        LibERC20.transferFrom(ghstContract, _from, address(0xFFfFfFffFFfffFFfFFfFFFFFffFFFffffFfFFFfF), burnShare);
        LibERC20.transferFrom(ghstContract, _from, s.pixelCraft, companyShare);
        LibERC20.transferFrom(ghstContract, _from, s.rarityFarming, rarityFarmShare);
        LibERC20.transferFrom(ghstContract, _from, s.dao, daoShare);
    }

    function sqrt(uint256 x) internal pure returns (uint256 y) {
        uint256 z = (x + 1) / 2;
        y = x;
        while (z < y) {
            y = z;
            z = (x / z + z) / 2;
        }
    }

    function createRandomNMB(uint number) public view returns(uint){
        return uint(blockhash(block.number-1)) % number;
    }

    function validateAndLowerName(string memory _name) internal pure returns (string memory) {
        bytes memory name = abi.encodePacked(_name);
        uint256 len = name.length;
        require(len != 0, "LibPyraniha: name can't be 0 chars");
        require(len < 26, "LibPyraniha: name can't be greater than 25 characters");
        uint256 char = uint256(uint8(name[0]));
        require(char != 32, "LibPyraniha: first char of name can't be a space");
        char = uint256(uint8(name[len - 1]));
        require(char != 32, "LibPyraniha: last char of name can't be a space");
        for (uint256 i; i < len; i++) {
            char = uint256(uint8(name[i]));
            require(char > 31 && char < 127, "LibPyraniha: invalid character in Pyraniha name.");
            if (char < 91 && char > 64) {
                name[i] = bytes1(uint8(char + 32));
            }
        }
        return string(name);
    }

    // function addTokenToUser(address _to, uint256 _tokenId) internal {}

    // function removeTokenFromUser(address _from, uint256 _tokenId) internal {}

    function transfer(
        address _from,
        address _to,
        uint256 _tokenId
    ) internal {
        AppStorage storage s = LibAppStorage.diamondStorage();
        // remove
        uint256 index = s.ownerTokenIdIndexes[_from][_tokenId];
        uint256 lastIndex = s.ownerTokenIds[_from].length - 1;
        if (index != lastIndex) {
            uint32 lastTokenId = s.ownerTokenIds[_from][lastIndex];
            s.ownerTokenIds[_from][index] = lastTokenId;
            s.ownerTokenIdIndexes[_from][lastTokenId] = index;
        }
        s.ownerTokenIds[_from].pop();
        delete s.ownerTokenIdIndexes[_from][_tokenId];
        if (s.approved[_tokenId] != address(0)) {
            delete s.approved[_tokenId];
            emit LibERC721.Approval(_from, address(0), _tokenId);
        }
        // add
        s.pyranihas[_tokenId].owner = _to;
        s.ownerTokenIdIndexes[_to][_tokenId] = s.ownerTokenIds[_to].length;
        s.ownerTokenIds[_to].push(uint32(_tokenId));
        emit LibERC721.Transfer(_from, _to, _tokenId);
    }

  /*  function verify(uint256 _tokenId) internal pure {
       // if (_tokenId < 10) {}
       // revert("Not verified");
    }
    */
}




  

}