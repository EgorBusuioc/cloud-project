package com.motivation.ietec_cdc.dto;

import lombok.AllArgsConstructor;
import lombok.Data;

/**
 * @author EgorBusuioc
 * 09.06.2025
 */
@Data
@AllArgsConstructor
public abstract class PasswordRequestBase {
    private String email;
}
