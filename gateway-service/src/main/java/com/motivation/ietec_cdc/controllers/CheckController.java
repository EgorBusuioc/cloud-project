package com.motivation.ietec_cdc.controllers;

import org.springframework.beans.factory.annotation.Value;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RestController;

/**
 * @author EgorBusuioc
 * 18.07.2025
 */
@RestController
public class CheckController {

    @Value("${server.ip}")
    private String serverIp; // Assuming this is injected from application properties

    @GetMapping("/check")
    public ResponseEntity<String> check() {
        return ResponseEntity.ok("Gateway is running on IP: " + serverIp);
    }
}
