package com.motivation.ietec_cdc.filters;

import lombok.RequiredArgsConstructor;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.cloud.gateway.filter.GatewayFilterChain;
import org.springframework.cloud.gateway.filter.GlobalFilter;
import org.springframework.core.Ordered;
import org.springframework.http.HttpHeaders;
import org.springframework.http.server.reactive.ServerHttpRequest;
import org.springframework.security.oauth2.jwt.ReactiveJwtDecoder;
import org.springframework.stereotype.Component;
import org.springframework.web.server.ServerWebExchange;
import reactor.core.publisher.Mono;

/**
 * This class is responsible for decoding JWT tokens and adding user information to the request headers.
 * It implements the GlobalFilter interface and is used in the Spring Cloud Gateway.
 * @author EgorBusuioc
 * 19.05.2025
 */
@Component
@RequiredArgsConstructor
public class JWTGlobalFilter implements GlobalFilter, Ordered {

    private final ReactiveJwtDecoder jwtDecoder;

    @Value("${secret-api.key}")
    private String secretKey; // Assuming this is injected from application properties

    @Value("${server.ip}")
    private String serverIp; // Assuming this is injected from application properties

    @Override
    public Mono<Void> filter(ServerWebExchange exchange, GatewayFilterChain chain) {

        String authHeader = exchange.getRequest().getHeaders().getFirst(HttpHeaders.AUTHORIZATION);

        if (authHeader == null || !authHeader.startsWith("Bearer ")) {
            return chain.filter(exchange);
        }

        String jwtToken = authHeader.substring(7);

        return jwtDecoder.decode(jwtToken).flatMap(token -> {
            String userId = token.getClaimAsString("user-id");
            String userRole = token.getClaimAsString("role");

            ServerHttpRequest request = exchange.getRequest().mutate()
                    .header("X-User-Id", userId)
                    .header("X-User-Role", userRole)
                    .header("X-API-KEY", secretKey) // Adding the secret key to the request headers
                    .header("GatewayIP", serverIp) // Adding the server IP to the request headers
                    .build();

            return chain.filter(exchange.mutate().request(request).build());
        });
    }

    @Override
    public int getOrder() {
        return -1;
    }
}
