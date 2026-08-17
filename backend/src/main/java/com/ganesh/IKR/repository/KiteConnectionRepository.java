package com.ganesh.IKR.repository;

import com.ganesh.IKR.entity.KiteConnection;
import java.util.Optional;
import org.springframework.data.jpa.repository.JpaRepository;

public interface KiteConnectionRepository extends JpaRepository<KiteConnection, Long> {
    Optional<KiteConnection> findByUserId(Long userId);
}
